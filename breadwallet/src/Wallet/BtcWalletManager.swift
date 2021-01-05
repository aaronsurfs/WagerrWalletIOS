//
//  BtcWalletManager.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2018-04-04.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import SystemConfiguration
import UIKit

class BTCWalletManager : WalletManager {
    let currency: CurrencyDef
    var masterPubKey = BRMasterPubKey()
    var earliestKeyTime: TimeInterval = 0
    var db: CoreDatabase?
    var wallet: BRWallet?
    private let progressUpdateInterval: TimeInterval = 0.5
    private let updateDebounceInterval: TimeInterval = 0.4
    private let updateEventInterval: TimeInterval = 5
    private let minuteInterval: TimeInterval = 60
    private var progressTimer: Timer?
    private var lastBlockHeightKey: String {
        return "LastBlockHeightKey-\(currency.code)"
    }
    private var lastBlockHeight: UInt32 {
        set { UserDefaults.standard.set(newValue, forKey: lastBlockHeightKey) }
        get { return UInt32(UserDefaults.standard.integer(forKey: lastBlockHeightKey)) }
    }
    private var retryTimer: RetryTimer?
    private var updateTimer: Timer?
    private var eventUpdateTimer: Timer?
    private var minuteTimer: Timer?
    
    public var parlayBet : ParlayBetEntity

    var kvStore: BRReplicatedKVStore? {
        didSet { requestTxUpdate() }
    }

    func initWallet(callback: @escaping (Bool) -> Void) {
        db?.loadTransactions { txns in
            guard self.masterPubKey != BRMasterPubKey() else {
                #if !Debug
                self.db?.delete()
                #endif
                return callback(false)
            }
            self.wallet = BRWallet(transactions: txns, masterPubKey: self.masterPubKey, listener: self)
            if let wallet = self.wallet {
                Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
                Store.perform(action: WalletChange(self.currency).set(self.currency.state!.mutate(receiveAddress: wallet.receiveAddress)))
            }
            callback(self.wallet != nil)
        }
        if (self.currency.code == Currencies.btc.code )    {
            db?.loadEvents(0, Date(timeIntervalSinceNow: 12 * 60.0).timeIntervalSinceReferenceDate, callback: { events in
                Store.perform(action: WalletChange(self.currency).setEvents(events as! [BetEventViewModel]))
            })
        }
    }

    func initWallet(transactions: [BRTxRef]) {
        guard self.masterPubKey != BRMasterPubKey() else {
            #if !Debug
            self.db?.delete()
            #endif
            return
        }
        self.wallet = BRWallet(transactions: transactions, masterPubKey: self.masterPubKey, listener: self)
        if let wallet = self.wallet {
            Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
            Store.perform(action: WalletChange(self.currency).set(self.currency.state!.mutate(receiveAddress: wallet.receiveAddress)))
        }
    }

    func initPeerManager(blocks: [BRBlockRef?]) {
        guard let wallet = self.wallet else { return }
        self.peerManager = BRPeerManager(currency: currency, wallet: wallet, earliestKeyTime: earliestKeyTime,
                                         blocks: blocks, peers: [], listener: self)
    }

    func initPeerManager(callback: @escaping () -> Void) {
        db?.loadBlocks { [unowned self] blocks in
            self.db?.loadPeers { peers in
                guard let wallet = self.wallet else { return }
                self.peerManager = BRPeerManager(currency: self.currency, wallet: wallet, earliestKeyTime: self.earliestKeyTime,
                                                 blocks: blocks, peers: peers, listener: self)
                callback()
            }
        }
    }

    var apiClient: BRAPIClient? {
        guard self.masterPubKey != BRMasterPubKey() else { return nil }
        return lazyAPIClient
    }

    var peerManager: BRPeerManager?

    private lazy var lazyAPIClient: BRAPIClient? = {
        guard let wallet = self.wallet else { return nil }
        return BRAPIClient(authenticator: self)
    }()

    init(currency: CurrencyDef, masterPubKey: BRMasterPubKey, earliestKeyTime: TimeInterval, dbPath: String? = nil) throws {
        self.currency = currency
        self.masterPubKey = masterPubKey
        self.earliestKeyTime = earliestKeyTime
        if let path = dbPath {
            self.db = CoreDatabase(dbPath: path)
        } else {
            self.db = CoreDatabase()
        }
        self.parlayBet = ParlayBetEntity()
        self.minuteTimer = Timer.scheduledTimer(timeInterval: minuteInterval, target: self, selector: #selector(updateTransactions), userInfo: nil, repeats: true)
    }

    var isWatchOnly: Bool {
        let mpkData = Data(masterPubKey: masterPubKey)
        return mpkData.count == 0
    }
}

extension BTCWalletManager : BRPeerManagerListener, Trackable {

    func syncStarted() {
        DispatchQueue.main.async() {
            self.db?.setDBFileAttributes()
            self.progressTimer = Timer.scheduledTimer(timeInterval: self.progressUpdateInterval, target: self, selector: #selector(self.updateProgress), userInfo: nil, repeats: true)
            Store.perform(action: WalletChange(self.currency).setSyncingState(.syncing))
        }
    }

    func syncStopped(_ error: BRPeerManagerError?) {
        DispatchQueue.main.async() {
            if UIApplication.shared.applicationState != .active {
                DispatchQueue.walletQueue.async {
                    self.peerManager?.disconnect()
                }
                return
            }

            switch error {
            case .some(let .posixError(errorCode, description)):

                Store.perform(action: WalletChange(self.currency).setSyncingState(.connecting))
                self.saveEvent("event.syncErrorMessage", attributes: ["message": "\(description) (\(errorCode))"])
                if self.retryTimer == nil && self.networkIsReachable() {
                    self.retryTimer = RetryTimer()
                    self.retryTimer?.callback = strongify(self) { myself in
                        Store.trigger(name: .retrySync(self.currency))
                    }
                    self.retryTimer?.start()
                }
            case .none:
                self.retryTimer?.stop()
                self.retryTimer = nil
                if let height = self.peerManager?.lastBlockHeight {
                    self.lastBlockHeight = height
                }
                self.progressTimer?.invalidate()
                self.progressTimer = nil
                Store.perform(action: WalletChange(self.currency).setSyncingState(.success))
            }
        }
    }

    func txStatusUpdate() {
        DispatchQueue.main.async { [weak self] in
            self?.requestTxUpdate()
        }
    }

    func saveBlocks(_ replace: Bool, _ blocks: [BRBlockRef?]) {
        db?.saveBlocks(replace, blocks)
    }

    func savePeers(_ replace: Bool, _ peers: [BRPeer]) {
        db?.savePeers(replace, peers)
    }

    func networkIsReachable() -> Bool {
        var flags: SCNetworkReachabilityFlags = []
        var zeroAddress = sockaddr()
        zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
        zeroAddress.sa_family = sa_family_t(AF_INET)
        guard let reachability = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else { return false }
        if !SCNetworkReachabilityGetFlags(reachability, &flags) { return false }
        return flags.contains(.reachable) && !flags.contains(.connectionRequired)
    }

    @objc private func updateProgress() {
        DispatchQueue.walletQueue.async {
            guard let progress = self.peerManager?.syncProgress(fromStartHeight: self.lastBlockHeight), let timestamp = self.peerManager?.lastBlockTimestamp else { return }
            DispatchQueue.main.async {
                Store.perform(action: WalletChange(self.currency).setProgress(progress: progress, timestamp: timestamp))
                if let wallet = self.wallet {
                    Store.perform(action: WalletChange(self.currency).setBalance(UInt256(wallet.balance)))
                }
            }
        }
    }
}

extension BTCWalletManager : BRWalletListener {
    
    func balanceChanged(_ balance: UInt64) {
        DispatchQueue.main.async { [weak self] in
            guard let myself = self else { return }
            myself.checkForReceived(newBalance: balance)
            Store.perform(action: WalletChange(myself.currency).setBalance(UInt256(balance)))
            myself.requestTxUpdate()
        }
    }

    func txAdded(_ tx: BRTxRef) {
        db?.txAdded(tx)
    }

    func txUpdated(_ txHashes: [UInt256], blockHeight: UInt32, timestamp: UInt32) {
        db?.txUpdated(txHashes, blockHeight: blockHeight, timestamp: timestamp)
    }

    func txBetUpdated(_ betTxs: UnsafeBufferPointer<BRTransaction>, blockHeight: UInt32, timestamp: UInt32) {
        // parse and store
        let opCodeManager = WagerrOpCodeManager();
        for tx in betTxs {
            let txRef = BRTxRef.allocate(capacity: 1)
            defer { txRef.deallocate() }
            txRef.initialize(to: tx)
            _ = opCodeManager.decodeBetTransaction( txRef , db: self.db!)
        }
        DispatchQueue.main.async { [weak self] in
            self?.requestEventUpdate()
        }
    }
    
    func txDeleted(_ txHash: UInt256, notifyUser: Bool, recommendRescan: Bool) {
        if notifyUser {
            if recommendRescan {
                DispatchQueue.main.async { [weak self] in
                    guard let myself = self else { return }
                    Store.perform(action: WalletChange(myself.currency).setRecommendScan(recommendRescan)) }
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.requestTxUpdate()
        }
        db?.txDeleted(txHash, notifyUser: notifyUser, recommendRescan: true)
    }

    private func checkForReceived(newBalance: UInt64) {
        //TODO:ETH
        if let oldBalance = currency.state?.balance?.asUInt64 {
            if newBalance > oldBalance {
                if let walletState = currency.state {
                    Store.perform(action: WalletChange(currency).set(walletState.mutate(receiveAddress: wallet?.receiveAddress)))
                    if currency.state?.syncState == .success {
                        showReceived(amount: newBalance - oldBalance)
                    }
                }
            }
        }
    }

    private func showReceived(amount: UInt64) {
        if let rate = currency.state?.currentRate {
            let tokenAmount = Amount(amount: UInt256(amount),
                                     currency: currency,
                                     rate: nil,
                                     minimumFractionDigits: 0)
            let fiatAmount = Amount(amount: UInt256(amount),
                                    currency: currency,
                                    rate: rate,
                                    minimumFractionDigits: 0)
            let primary = Store.state.isBtcSwapped ? fiatAmount.description : tokenAmount.description
            let secondary = Store.state.isBtcSwapped ? tokenAmount.description : fiatAmount.description
            let message = String(format: S.TransactionDetails.received, "\(primary) (\(secondary))")
            Store.trigger(name: .lightWeightAlert(message))
            showLocalNotification(message: message)
            ping()
        }
    }

    private func requestTxUpdate() {
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(timeInterval: updateDebounceInterval, target: self, selector: #selector(updateTransactions), userInfo: nil, repeats: false)
        }
    }

    @objc private func updateTransactions() {
        if updateTimer != nil   {
            updateTimer?.invalidate()
        }
        updateTimer = nil
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let myself = self else { return }
            guard let txRefs = myself.wallet?.transactions else { return }
            guard let currentRate = myself.currency.state?.currentRate else { return }
            let transactions = myself.makeTransactionViewModels(transactions: txRefs,
                                                                rate: currentRate)
            if transactions.count > 0 {
                DispatchQueue.main.async {
                    Store.perform(action: WalletChange(myself.currency).setTransactions(transactions))
                }
            }
        }
    }

    private func requestEventUpdate() {
        // ignore if not fully synced
        if eventUpdateTimer == nil && Store.state.wallets[self.currency.code]?.syncState == SyncState.success {
            eventUpdateTimer = Timer.scheduledTimer(timeInterval: updateEventInterval, target: self, selector: #selector(updateEvents), userInfo: nil, repeats: false)
        }
    }
    
    @objc func updateEvents() {
        if eventUpdateTimer != nil    {
            eventUpdateTimer?.invalidate()
        }
        eventUpdateTimer = nil
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let myself = self else { return }
            myself.db?.cleanChainBugs()
            myself.db?.fixPKCorruptions()
            myself.db?.cleanDuplicateMappings( namespaceID: MappingNamespaceType.SPORT )
            myself.db?.cleanDuplicateMappings( namespaceID: MappingNamespaceType.ROUNDS )
            myself.db?.cleanDuplicateMappings( namespaceID: MappingNamespaceType.TOURNAMENT )
            myself.db?.cleanDuplicateMappings( namespaceID: MappingNamespaceType.TEAM_NAME )
            myself.db?.loadEvents(0, Date(timeIntervalSinceNow: 12 * 60.0).timeIntervalSinceReferenceDate, callback: { events in
                    Store.perform(action: WalletChange(myself.currency).setEvents(events as! [BetEventViewModel]))
            })
        }
    }
    
    func makeTransactionViewModels(transactions: [BRTxRef?], rate: Rate?) -> [Transaction] {
        return transactions.compactMap{ $0 }.sorted {
            if $0.pointee.timestamp == 0 {
                return true
            } else if $1.pointee.timestamp == 0 {
                return false
            } else {
                return $0.pointee.timestamp > $1.pointee.timestamp
            }
            }.compactMap {
                return BtcTransaction($0, walletManager: self, kvStore: kvStore, rate: rate)
        }
    }
}
