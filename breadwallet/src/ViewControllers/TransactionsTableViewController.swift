//
//  TransactionsTableViewController.swift
//  breadwallet
//
//  Created by Adrian Corscadden on 2016-11-16.
//  Copyright © 2016 breadwallet LLC. All rights reserved.
//

import UIKit
import SafariServices

private let promptDelay: TimeInterval = 0.6

class TransactionsTableViewController : UITableViewController, Subscriber, Trackable {

    //MARK: - Public
    init(currency: CurrencyDef, walletManager: WalletManager, didSelectTransaction: @escaping (WgrTransactionInfo, Int) -> Void) {
        self.currency = currency
        self.walletManager = walletManager
        self.didSelectTransaction = didSelectTransaction
        self.isBtcSwapped = Store.state.isBtcSwapped
        super.init(nibName: nil, bundle: nil)
    }

    let didSelectTransaction: (WgrTransactionInfo, Int) -> Void

    var filters: [TransactionFilter] = [] {
        didSet {
            // load all missing event data
            if self.transactionInfo.count == self.allTransactions.count  {  // finished
                self.doFilter()
                return
            }
            for tx in allTransactions   {
                if transactionInfo[tx.hash] == nil  {
                    WgrTransactionInfo.create(tx: tx as! BtcTransaction, wm: walletManager as! BTCWalletManager, callback: { txInfo in
                        self.transactionInfo[tx.hash] = txInfo
                        if self.transactionInfo.count == self.allTransactions.count  {  // finished
                            self.doFilter()
                        }
                    })
                }
            }
        }
    }
    
    func doFilter() {
        let allTxInfo = Array(transactionInfo.values)
        var filteredTxInfo : [ WgrTransactionInfo ]
        filteredTxInfo = filters.reduce(allTxInfo, { $0.filter($1) })
        transactions = filteredTxInfo.map {$0.transaction}.sorted(by: { $0.timestamp > $1.timestamp } )
        tableView.reloadData()
    }

    //MARK: - Private
    private let walletManager: WalletManager
    private let currency: CurrencyDef
    
    private let headerCellIdentifier = "HeaderCellIdentifier"
    private let transactionCellIdentifier = "TransactionCellIdentifier"
    private var transactions: [Transaction] = []
    private var allTransactions: [Transaction] = [] {
        didSet { transactions = allTransactions }
    }
    private var transactionInfo = [ String : WgrTransactionInfo ]()
    
    private var isBtcSwapped: Bool {
        didSet { reload() }
    }
    private var rate: Rate? {
        didSet { reload() }
    }
    private let emptyMessage = UILabel.wrapping(font: .customBody(size: 16.0), color: .grayTextTint)
    
    //TODO:BCH replace with recommend rescan / tx failed prompt
    private var currentPrompt: Prompt? {
        didSet {
            if currentPrompt != nil && oldValue == nil {
                tableView.beginUpdates()
                tableView.insertSections(IndexSet(integer: 0), with: .automatic)
                tableView.endUpdates()
            } else if currentPrompt == nil && oldValue != nil {
                tableView.beginUpdates()
                tableView.deleteSections(IndexSet(integer: 0), with: .automatic)
                tableView.endUpdates()
            }
        }
    }
    private var hasExtraSection: Bool {
        return (currentPrompt != nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(TxListCell.self, forCellReuseIdentifier: transactionCellIdentifier)
        tableView.register(TxListCell.self, forCellReuseIdentifier: headerCellIdentifier)

        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 60.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.backgroundColor = .whiteBackground
        
        emptyMessage.textAlignment = .center
        emptyMessage.text = S.TransactionDetails.emptyMessage
        
        setContentInset()

        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        Store.subscribe(self,
                        selector: { $0.isBtcSwapped != $1.isBtcSwapped },
                        callback: { self.isBtcSwapped = $0.isBtcSwapped })
        Store.subscribe(self,
                        selector: { $0[self.currency]?.currentRate != $1[self.currency]?.currentRate},
                        callback: {
                            self.rate = $0[self.currency]?.currentRate
        })
        Store.subscribe(self, selector: { $0[self.currency]?.maxDigits != $1[self.currency]?.maxDigits }, callback: {_ in
            self.reload()
        })
        
        Store.subscribe(self, selector: { $0[self.currency]?.recommendRescan != $1[self.currency]?.recommendRescan }, callback: { _ in
            //TODO:BCH show failed tx
        })
        
        Store.subscribe(self, name: .txMemoUpdated(""), callback: {
            guard let trigger = $0 else { return }
            if case .txMemoUpdated(let txHash) = trigger {
                self.reload(txHash: txHash)
            }
        })
        
        Store.subscribe(self, selector: {
            guard let oldTransactions = $0[self.currency]?.transactions else { return false }
            guard let newTransactions = $1[self.currency]?.transactions else { return false }
            return oldTransactions != newTransactions },
                        callback: { state in
                            self.allTransactions = state[self.currency]?.transactions ?? [Transaction]()
                            self.reload()
        })
    }

    private func setContentInset() {
        let insets = UIEdgeInsets(top: accountHeaderHeight - 64.0 - (E.isIPhoneX ? 28.0 : 0.0), left: 0, bottom: accountFooterHeight + C.padding[2], right: 0)
        tableView.contentInset = insets
        tableView.scrollIndicatorInsets = insets
    }

    private func reload(txHash: String) {
        self.transactions.enumerated().forEach { i, tx in
            if tx.hash == txHash {
                DispatchQueue.main.async {
                    self.tableView.reload(row: i, section: self.hasExtraSection ? 1 : 0)
                }
            }
        }
    }

    // MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return hasExtraSection ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if hasExtraSection && section == 0 {
            return 1
        } else {
            return transactions.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if hasExtraSection && indexPath.section == 0 {
            return headerCell(tableView: tableView, indexPath: indexPath)
        } else {
            return transactionCell(tableView: tableView, indexPath: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if hasExtraSection && section == 1 {
            return C.padding[2]
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if hasExtraSection && section == 1 {
            return UIView(color: .clear)
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if hasExtraSection && indexPath.section == 0 { return }
        let tx = transactions[indexPath.row]
        if transactionInfo[tx.hash] != nil  {
            didSelectTransaction(transactionInfo[tx.hash]!, indexPath.row)
        }
    }

    private func reload() {
        tableView.reloadData()
        if transactions.count == 0 {
            if emptyMessage.superview == nil {
                tableView.addSubview(emptyMessage)
                emptyMessage.constrain([
                    emptyMessage.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
                    emptyMessage.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -accountHeaderHeight),
                    emptyMessage.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -C.padding[2]) ])
            }
        } else {
            emptyMessage.removeFromSuperview()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: - Cell Builders
extension TransactionsTableViewController {

    private func headerCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: headerCellIdentifier, for: indexPath)
        if let containerCell = cell as? TxListCell {
            if let prompt = currentPrompt {
                containerCell.contentView.addSubview(prompt)
                prompt.constrain(toSuperviewEdges: nil)
            }
        }
        return cell
    }

    private func transactionCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: transactionCellIdentifier, for: indexPath) as! TxListCell
        let rate = self.rate ?? Rate.empty
        let tx = transactions[indexPath.row]
        let viewModel = TxListViewModel(tx: tx)
        
        if transactionInfo[tx.hash] != nil  {
            transactionInfo[tx.hash]?.transaction = tx as! BtcTransaction
            transactionInfo[tx.hash]?.currentHeight = walletManager.peerManager!.lastBlockHeight    // update currheight for payouts
            cell.setTransaction(viewModel,
                isBtcSwapped: self.isBtcSwapped,
                rate: rate,
                maxDigits: self.currency.state?.maxDigits ?? self.currency.commonUnit.decimals,
                isSyncing: self.currency.state?.syncState != .success,
                txInfo: transactionInfo[tx.hash]!
            )
        }
        else    {
            WgrTransactionInfo.create(tx: tx as! BtcTransaction, wm: walletManager as! BTCWalletManager, callback: { txInfo in
                self.transactionInfo[tx.hash] = txInfo
                self.reload( txHash: tx.hash )
            })
        }
        
        return cell
    }
}
