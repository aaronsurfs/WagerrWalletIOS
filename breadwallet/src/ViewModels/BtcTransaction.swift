//
//  BtcTransaction.swift
//  breadwallet
//
//  Created by Ehsan Rezaie on 2018-01-12.
//  Copyright © 2018 breadwallet LLC. All rights reserved.
//

import Foundation
import BRCore
import UIKit

struct WgrTransactionInfo {
    var transaction : BtcTransaction
    var betEntity : BetEntity?
    var betResult : BetResult?
    var betEvent : BetEventViewModel?
    var currentHeight : UInt32
    var explorerInfo : ExplorerTxVout?
    var explorerPayoutInfo : [ExplorerTxPayoutData]?
    
    init(tx: BtcTransaction, ent: BetEntity?, res: BetResult?, event: BetEventViewModel?, currHeight: UInt32)  {
        self.transaction = tx
        self.betEntity = ent
        self.betResult = res
        self.betEvent = event
        self.currentHeight = currHeight
    }
    
    static func create(tx: BtcTransaction, wm: BTCWalletManager, callback: @escaping ( WgrTransactionInfo? ) -> Void  )   {
        var ent : BetEntity?
        var res : BetResult?
        var event : BetEventViewModel?
        let currHeight = wm.peerManager!.lastBlockHeight
        
        let opCodeManager = WagerrOpCodeManager();
        
        ent = opCodeManager.getEventIdFromCoreTx( (tx.getRawTransactionRef())  )
        if ent == nil {
            // results in block - 1 rule is no longer enforced (testnet July 2020), show generic "payout" then use API for tx detail
            callback( WgrTransactionInfo(tx: tx, ent: ent, res: res, event: event, currHeight: currHeight) )
             /*
            if tx.isCoinbase    {
                wm.db?.loadResultAtHeigh(blockHeight: Int(tx.blockHeight-1), callback: { result in
                    res = result
                    if result != nil    {
                        wm.db?.loadEvents( result!.eventID, 0, callback: { events in
                            event = events[0] ?? nil
                            callback( WgrTransactionInfo(tx: tx, ent: ent, res: res, event: event, currHeight: currHeight) )
                        })
                    }
                    else    {
                        callback( WgrTransactionInfo(tx: tx, ent: ent, res: res, event: event, currHeight: currHeight) )
                    }
                })
                
                callback( WgrTransactionInfo(tx: tx, ent: ent, res: nil, event: nil, currHeight: currHeight) )
            }
            else    {
                callback( WgrTransactionInfo(tx: tx, ent: ent, res: res, event: event, currHeight: currHeight) )
            }
             */
        }
        else    {
            if ent!.eventID == 0    {
                callback( WgrTransactionInfo(tx: tx, ent: ent, res: res, event: event, currHeight: currHeight) )
            }
            else    {
                wm.db?.loadEvents( ent!.eventID, 0, callback: { events in
                    event = events[0] ?? nil
                    callback( WgrTransactionInfo(tx: tx, ent: ent, res: res, event: event, currHeight: currHeight) )
                })
            }
        }
    }
    
    var isCoinbase : Bool   {
        return transaction.isCoinbase
    }
    
    var isInmature : Bool   {
        let blockHeight = (W.Blockchain.txUnconfirmed==transaction.blockHeight) ? self.currentHeight : UInt32(transaction.blockHeight)
        return (Int(self.currentHeight)-Int(blockHeight)) <= W.Blockchain.payoutMaturity
    }
    
    var eventDateString : String {
        return (betEvent != nil) ? betEvent!.shortTimestamp : ""
    }
    
    var eventDetailString : NSAttributedString {
        var ret = NSMutableAttributedString(string: "")
        if explorerInfo != nil  {
            if explorerInfo?.isParlay == 1  {
                for leg in (explorerInfo?.legs)! {
                    ret.append(NSAttributedString(string: String.init(format: "%@ - %@", leg.homeTeam!, leg.awayTeam!)))
                    ret.append(NSAttributedString(string: String.init(format: " ( Stake: %@, Price: %@ , ", leg.market!, BetEventDatabaseModel.getOddTx( odd: UInt32(leg.price! * Double(EventMultipliers.ODDS_MULTIPLIER)) ))))
                    if leg.spread != nil  {
                        ret.append(NSAttributedString(string: String.init(format: "Spread: %@\n", leg.spread!)))
                    }
                    if leg.total != nil  {
                        ret.append(NSAttributedString(string: String.init(format: "Total: %@\n", leg.total!)))
                    }
                
                    if leg.homeScore != nil && leg.awayScore != nil {
                        ret.append(NSAttributedString(string:  String.init(format: "Score: %@ - %@ ", leg.homeScoreTx, leg.awayScoreTx)))
                    }
                    else    {
                        ret.append(NSAttributedString(string:  "Score: Pending "))
                    }
                    if leg.betOutcome != nil    {
                        ret.append(NSAttributedString(string: String.init(format: ", Outcome: %@ ", (leg.betResult)! )))
                        let image1Attachment = NSTextAttachment()
                        image1Attachment.image = UIImage(named: leg.resultIcon)
                        image1Attachment.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
                        let image1String = NSAttributedString(attachment: image1Attachment)
                        ret.append(image1String)
                    }
                    ret.append(NSAttributedString(string: " ) \n\n"));
                }
                ret.append(NSAttributedString(string: String.init(format: "Multi Event Price: %@, Outcome: %@ ", explorerInfo!.parlayPriceTx, (explorerInfo?.betResultType)!)))
                let image1Attachment = NSTextAttachment()
                image1Attachment.image = UIImage(named: explorerInfo!.resultIcon)
                image1Attachment.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
                let image1String = NSAttributedString(attachment: image1Attachment)
                ret.append(image1String)
                ret.append(NSAttributedString(string: " \n\n"));
            }
            else    {
                guard explorerInfo?.homeTeam != nil    else     { return ret }
                
                ret = NSMutableAttributedString(string: String.init(format: "%@ - %@", (explorerInfo?.homeTeam)!, (explorerInfo?.awayTeam)!) )

                ret.append(NSAttributedString(string: String.init(format: "\nPrice: %@, ", BetEventDatabaseModel.getOddTx( odd: UInt32((explorerInfo?.price!)! * Double(EventMultipliers.ODDS_MULTIPLIER)) ))))
                if explorerInfo?.total != nil && Double((explorerInfo?.total)!)! > 0.0  {
                    ret.append(NSAttributedString(string: String.init(format: "Total: %@\n", (explorerInfo?.total!)!)))
                }
                if explorerInfo?.spread != nil && Double((explorerInfo?.spread)!)! != 0.0  {
                    ret.append(NSAttributedString(string: String.init(format: "Spread: %@\n", (explorerInfo?.spread!)!)))
                }
                if explorerInfo?.homeScore != nil && explorerInfo?.awayScore != nil {
                    ret.append(NSAttributedString(string: String.init(format: "Score: %@ - %@ ", explorerInfo!.homeScoreTx, explorerInfo!.awayScoreTx)))
                }
                else    {
                    ret.append(NSAttributedString(string: "Score: Pending "))
                }
                
                if explorerInfo?.betResultType != nil    {
                    ret.append(NSAttributedString(string: String.init(format: ", Result: %@ ", (explorerInfo?.betResultType)! )))
                    let image1Attachment = NSTextAttachment()
                    image1Attachment.image = UIImage(named: explorerInfo!.resultIcon)
                    image1Attachment.bounds = CGRect(x: 0, y: 0, width: 24, height: 24)
                    let image1String = NSAttributedString(attachment: image1Attachment)
                    ret.append(image1String)
                }
            }
        }
        else    {
            if explorerPayoutInfo != nil  {
                for payout in explorerPayoutInfo!    {
                    ret.append(NSAttributedString(string: String.init(format: "Reward: %.4f \n", payout.payout! )))
                    for leg in (payout.legs)!   {
                        ret.append(NSAttributedString(string: leg.description + "\n"))
                    }
                    if payout.legs!.count > 1   {
                        ret.append(NSAttributedString(string: String.init(format: "Multi Event Price: %@\n", payout.parlayPriceTx)))
                    }
                    ret.append(NSAttributedString(string: "\n"))
                }
            }
            else {
                guard let _ = betEntity, let pb = betEntity?.parlayBet else    { return ret }
                for (eventID, outcome) in zip(pb.eventID, pb.outcome)   {
                    ret.append(NSAttributedString(string: String.init(format: "#%d - %@ \n", eventID, outcome.description)))
                }
            }
        }
        return ret
    }
    
    func getDescriptionStrings() -> ( date: String, description: String) {
        var txDesc: String = ""
        var txDate: String = ""
        
        if self.betEntity == nil {
            if self.isCoinbase {   // payout
                if self.betResult != nil {
                    if self.betEvent != nil {
                        txDesc = String.init(format: "%@ - %@", self.betEvent!.txHomeTeam, self.betEvent!.txAwayTeam)
                    }
                    else {
                        txDesc = String.init(format: "Event #%d info not available", self.betEvent!.eventID)
                    }
                    txDate = String.init(format: "REWARD Event #%d", self.betEvent!.eventID)
                }
                else    {
                    //txDesc = String.init(format: "Result not available at height %@", transaction.blockHeight)
                    txDate = "REWARD"
                }
                if isInmature {
                    var confirmations = Int(self.currentHeight)-Int(transaction.blockHeight)
                    if confirmations<0  { confirmations=0 }
                    txDate += String.init(format: " (%d/%d)", confirmations, W.Blockchain.payoutMaturity)
                }
            }
            else    {   // normal tx
                txDesc = ""
            }
        }
        else    {   // regular bet
            let eventID = self.betEntity!.eventID
            if eventID == 0 {
                txDesc = String.init(format: "MULTI (%d)", self.betEntity!.parlayBet!.eventID.count )
                txDate = "STAKE"
            }
            else    {
                if self.betEvent != nil {
                    txDesc = self.betEvent!.getDescriptionForBet(bet: self.betEntity!)
                    txDate = self.betEvent!.getEventDateForBet(bet: self.betEntity!)
                }
                else {
                    txDesc = String.init(format: "Event #%d info not available", self.betEntity!.eventID)
                    txDate = String.init(format: "STAKE %@ ", self.betEntity!.outcome.description)
                }
            }
        }
        return ( date: txDate, description: txDesc )
    }
}

/// Wrapper for BTC transaction model + metadata
struct BtcTransaction: Transaction {
    
    // MARK: Transaction Properties
    
    let currency: CurrencyDef
    let hash: String
    let status: TransactionStatus
    let direction: TransactionDirection
    let toAddress: String
    let timestamp: TimeInterval
    let blockHeight: UInt64
    let confirmations: UInt64
    let isValid: Bool
    let metaDataContainer: MetaDataContainer?
    let kvStore: BRReplicatedKVStore?
    
    // MARK: BTC-specific properties
    
    var rawTransaction: BRTransaction {
        return tx.pointee
    }
    
    func getRawTransactionRef() -> BRTxRef {
        return tx
    }
    
    var isCoinbase : Bool   {
        return tx.pointee.inCount==1 && tx.pointee.outCount>1 && tx.pointee.outputs[0].swiftAddress.isEmpty &&  tx.pointee.inputs[0].swiftAddress.isEmpty
    }
    
    let amount: UInt256
    let fee: UInt64
    let startingBalance: UInt64
    let endingBalance: UInt64
    
    // MARK: Private
    
    private let tx: BRTxRef
    
    // MARK: - Init
    
    init?(_ tx: BRTxRef, walletManager: BTCWalletManager, kvStore: BRReplicatedKVStore?, rate: Rate?) {
        guard let wallet = walletManager.wallet,
            let peerManager = walletManager.peerManager else { return nil }
        self.currency = walletManager.currency
        self.tx = tx
        self.kvStore = kvStore
        
        let amountReceived = wallet.amountReceivedFromTx(tx)
        let amountSent = wallet.amountSentByTx(tx)
        
        let fee = wallet.feeForTx(tx) ?? 0
        self.fee = fee
        
        // addresses from outputs
        let myAddress = tx.outputs.filter({ output in
            wallet.containsAddress(output.swiftAddress)
        }).first?.swiftAddress ?? ""
        let otherAddress = tx.outputs.filter({ output in
            !wallet.containsAddress(output.swiftAddress)
        }).first?.swiftAddress ?? ""
        
        // direction
        var direction: TransactionDirection
        if amountSent > 0 && (amountReceived + fee) == amountSent {
            direction = .moved
        } else if amountSent > 0 {
            direction = .sent
        } else {
            direction = .received
        }
        self.direction = direction
        
        let endingBalance: UInt64 = wallet.balanceAfterTx(tx)
        var startingBalance: UInt64
        var address: String
        var amount: UInt64
        switch direction {
        case .received:
            address = myAddress
            amount = amountReceived
            startingBalance = endingBalance.subtractingReportingOverflow(amount).0.subtractingReportingOverflow(fee).0
        case .sent:
            address = otherAddress
            if amountSent > (amountReceived + fee)  {   // avoid crash on corrupt data
                amount = amountSent - amountReceived - fee
            }
            else    {
                amount = 0
            }
            startingBalance = endingBalance.addingReportingOverflow(amount).0.addingReportingOverflow(fee).0
        case .moved:
            address = myAddress
            amount = amountSent
            startingBalance = endingBalance.addingReportingOverflow(self.fee).0
        }
        self.amount = UInt256(amount)
        self.startingBalance = startingBalance
        self.endingBalance = endingBalance
        
        toAddress = currency.matches(Currencies.bch) ? address.bCashAddr : address
        
        hash = tx.pointee.txHash.description
        timestamp = TimeInterval(tx.pointee.timestamp)
        isValid = wallet.transactionIsValid(tx)
        blockHeight = (tx.pointee.blockHeight == UInt32.max) ? UInt64.max :  UInt64(tx.pointee.blockHeight)
        
        let lastBlockHeight = UInt64(peerManager.lastBlockHeight)
        confirmations = blockHeight > lastBlockHeight
            ? 0
            : (lastBlockHeight - blockHeight) + 1
        
        if isValid {
            switch confirmations {
            case 0:
                status = .pending
            case 1..<6:
                status = .confirmed
            default:
                status = .complete
            }
        } else {
            status = .invalid
        }
        
        // metadata
        if let kvStore = kvStore {
            metaDataContainer = MetaDataContainer(key: tx.pointee.txHash.txKey, kvStore: kvStore)
            if let rate = rate,
                confirmations < 6 && direction == .received {
                metaDataContainer!.createMetaData(tx: self, rate: rate)
            }
        } else {
            metaDataContainer = nil
        }
    }
}
