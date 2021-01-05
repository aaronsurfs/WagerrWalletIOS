//
//  InstaSwapEntities.swift
//  Wagerr Pro
//
//  Created by MIP on 12/6/2020.
//  Copyright © 2020 Wagerr Ltd. All rights reserved.
//

import Foundation
import UIKit

enum ExplorerTxResult {
    case success(ExplorerTxData)
    case error(String)
}

struct ExplorerTxData : Codable {
    let blockHash : String?
    let blockHeight : Int?
    let createdAt : String?
    let txId : String?
    let version : Int?
    let vin : [ExplorerTxVin]?
    let vout : [ExplorerTxVout]?

    enum CodingKeys: String, CodingKey {
        case blockHash = "blockHash"
        case blockHeight = "blockHeight"
        case createdAt = "createdAt"
        case txId = "txId"
        case version = "version"
        case vin = "vin"
        case vout = "vout"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        blockHash = try values.decodeIfPresent(String.self, forKey: .blockHash)
        blockHeight = try values.decodeIfPresent(Int.self, forKey: .blockHeight)
        createdAt = try values.decodeIfPresent(String.self, forKey: .createdAt)
        txId = try values.decodeIfPresent(String.self, forKey: .txId)
        version = try values.decodeIfPresent(Int.self, forKey: .version)
        vin = try values.decodeIfPresent([ExplorerTxVin].self, forKey: .vin)
        vout = try values.decodeIfPresent([ExplorerTxVout].self, forKey: .vout)
    }
}

struct ExplorerTxVin : Codable {
    let address : String?
    let value : Double?

    enum CodingKeys: String, CodingKey {

        case address = "address"
        case value = "value"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        address = try values.decodeIfPresent(String.self, forKey: .address)
        value = try values.decodeIfPresent(Double.self, forKey: .value)
    }
}

struct ExplorerTxVout : Codable {
    let _id : String?
    let address : String?
    let n : Int?
    let value : Double?
    let price : Double?
    let payout : Double?
    let payoutTxId : String?
    let payoutNout : Int?
    let completed : Bool?
    let betResultType : String?
    let spread : String?
    let total : String?
    let market : String?
    let eventId : String?
    let betValue : Double?
    let betValueUSD : Double?
    let homeTeam : String?
    let awayTeam : String?
    let league : String?
    let isParlay : Int?
    let homeScore : Int?
    let awayScore : Int?
    let legs : [ExplorerTxLegs]?

    enum CodingKeys: String, CodingKey {

        case _id = "_id"
        case address = "address"
        case n = "n"
        case value = "value"
        case payout = "payout"
        case payoutTxId = "payoutTxId"
        case payoutNout = "payoutNout"
        case completed = "completed"
        case betResultType = "betResultType"
        case price = "price"
        case total = "Total"
        case spread = "Spread"
        case market = "market"
        case eventId = "eventId"
        case betValue = "betValue"
        case betValueUSD = "betValueUSD"
        case homeTeam = "homeTeam"
        case awayTeam = "awayTeam"
        case homeScore = "homeScore"
        case awayScore = "awayScore"
        case league = "league"
        case isParlay = "isParlay"
        case legs = "legs"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        _id = try values.decodeIfPresent(String.self, forKey: ._id)
        address = try values.decodeIfPresent(String.self, forKey: .address)
        n = try values.decodeIfPresent(Int.self, forKey: .n)
        value = try values.decodeIfPresent(Double.self, forKey: .value)
        price = try values.decodeIfPresent(Double.self, forKey: .price)
        payout = try values.decodeIfPresent(Double.self, forKey: .payout)
        payoutTxId = try values.decodeIfPresent(String.self, forKey: .payoutTxId)
        payoutNout = try values.decodeIfPresent(Int.self, forKey: .payoutNout)
        completed = try values.decodeIfPresent(Bool.self, forKey: .completed)
        betResultType = try values.decodeIfPresent(String.self, forKey: .betResultType)
        total = try values.decodeIfPresent(String.self, forKey: .total)
        spread = try values.decodeIfPresent(String.self, forKey: .spread)
        market = try values.decodeIfPresent(String.self, forKey: .market)
        eventId = try values.decodeIfPresent(String.self, forKey: .eventId)
        betValue = try values.decodeIfPresent(Double.self, forKey: .betValue)
        betValueUSD = try values.decodeIfPresent(Double.self, forKey: .betValueUSD)
        homeTeam = try values.decodeIfPresent(String.self, forKey: .homeTeam)
        awayTeam = try values.decodeIfPresent(String.self, forKey: .awayTeam)
        homeScore = try values.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try values.decodeIfPresent(Int.self, forKey: .awayScore)
        league = try values.decodeIfPresent(String.self, forKey: .league)
        isParlay = try values.decodeIfPresent(Int.self, forKey: .isParlay)
        legs = try values.decodeIfPresent([ExplorerTxLegs].self, forKey: .legs)
    }

    var resultIcon : String  {
        switch (betResultType) {
            case "win":     return "win"
            case "lose":    return "loss"
            case "pending": return "pending"
            default:  return "pending"
        }
    }
    
    var homeScoreTx : String    {
        return String(format: "%d", UInt32(homeScore!) / EventMultipliers.RESULT_MULTIPLIER )
    }
    var awayScoreTx : String    {
        return String(format: "%d", UInt32(awayScore!) / EventMultipliers.RESULT_MULTIPLIER )
    }
    var parlayPrice : UInt32    {
        guard legs != nil else { return 0 }
        var ret : Float = 1.0
        for leg in legs! {
            ret *= Float(leg.price!)
        }
        return UInt32( ret * Float(EventMultipliers.ODDS_MULTIPLIER) )
    }
    
    var parlayPriceTx : String  {
        return BetEventDatabaseModel.getOddTx(odd: parlayPrice)
    }
}

struct ExplorerTxLegs : Codable {
    let price : Double?
    let eventId : String?
    let homeTeam : String?
    let awayTeam : String?
    let homeScore : Int?
    let awayScore : Int?
    let league : String?
    let market : String?
    let outcome : Int?
    let betResult : String?
    let eventResult : String?
    let spread : String?
    let total : String?

    enum CodingKeys: String, CodingKey {

        case price = "price"
        case eventId = "eventId"
        case homeTeam = "homeTeam"
        case awayTeam = "awayTeam"
        case homeScore = "homeScore"
        case awayScore = "awayScore"
        case league = "league"
        case market = "market"
        case outcome = "outcome"
        case betResult = "betResult"
        case eventResult = "eventResult"
        case spread = "Spread"
        case total = "Total"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        price = try values.decodeIfPresent(Double.self, forKey: .price)
        eventId = try values.decodeIfPresent(String.self, forKey: .eventId)
        homeTeam = try values.decodeIfPresent(String.self, forKey: .homeTeam)
        awayTeam = try values.decodeIfPresent(String.self, forKey: .awayTeam)
        homeScore = try values.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try values.decodeIfPresent(Int.self, forKey: .awayScore)
        league = try values.decodeIfPresent(String.self, forKey: .league)
        market = try values.decodeIfPresent(String.self, forKey: .market)
        outcome = try values.decodeIfPresent(Int.self, forKey: .outcome)
        betResult = try values.decodeIfPresent(String.self, forKey: .betResult)
        eventResult = try values.decodeIfPresent(String.self, forKey: .eventResult)
        total = try values.decodeIfPresent(String.self, forKey: .total)
        spread = try values.decodeIfPresent(String.self, forKey: .spread)
    }

    var resultIcon : String  {
        switch (betResult) {
            case "win":     return "win"
            case "lose":    return "loss"
            case "pending": return "pending"
            default:  return "pending"
        }
    }
    
    var betOutcome : BetOutcome? {
        return BetOutcome(rawValue: Int32(outcome!));
    }
    
    var homeScoreTx : String    {
        return String(format: "%d", UInt32(homeScore!) / EventMultipliers.RESULT_MULTIPLIER )
    }
    var awayScoreTx : String    {
        return String(format: "%d", UInt32(awayScore!) / EventMultipliers.RESULT_MULTIPLIER )
    }
}

enum ExplorerTxPayoutResult {
    case success(ExplorerTxPayoutData)
    case error(String)
}

struct ExplorerTxPayoutData : Codable {
    let betBlockHeight : Int?
    let betTxHash : String?
    let betTxOut : Int?
    let legs : [ExplorerTxPayoutLegs]?
    let address : String?
    let amount : Int?
    let time : Int?
    let completed : String?
    let betResultType : String?
    let payout : Double?
    let payoutTxHash : String?
    let payoutTxOut : Int?

    enum CodingKeys: String, CodingKey {

        case betBlockHeight = "betBlockHeight"
        case betTxHash = "betTxHash"
        case betTxOut = "betTxOut"
        case legs = "legs"
        case address = "address"
        case amount = "amount"
        case time = "time"
        case completed = "completed"
        case betResultType = "betResultType"
        case payout = "payout"
        case payoutTxHash = "payoutTxHash"
        case payoutTxOut = "payoutTxOut"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        betBlockHeight = try values.decodeIfPresent(Int.self, forKey: .betBlockHeight)
        betTxHash = try values.decodeIfPresent(String.self, forKey: .betTxHash)
        betTxOut = try values.decodeIfPresent(Int.self, forKey: .betTxOut)
        legs = try values.decodeIfPresent([ExplorerTxPayoutLegs].self, forKey: .legs)
        address = try values.decodeIfPresent(String.self, forKey: .address)
        amount = try values.decodeIfPresent(Int.self, forKey: .amount)
        time = try values.decodeIfPresent(Int.self, forKey: .time)
        completed = try values.decodeIfPresent(String.self, forKey: .completed)
        betResultType = try values.decodeIfPresent(String.self, forKey: .betResultType)
        payout = try values.decodeIfPresent(Double.self, forKey: .payout)
        payoutTxHash = try values.decodeIfPresent(String.self, forKey: .payoutTxHash)
        payoutTxOut = try values.decodeIfPresent(Int.self, forKey: .payoutTxOut)
    }

    var parlayPrice : UInt32    {
        guard legs != nil else { return 0 }
        var ret : Float = 1.0
        for leg in legs! {
            ret *= Float(leg.legPrice) / Float(EventMultipliers.ODDS_MULTIPLIER)
        }
        return UInt32( ret * Float(EventMultipliers.ODDS_MULTIPLIER) )
    }
    
    var parlayPriceTx : String  {
        return BetEventDatabaseModel.getOddTx(odd: parlayPrice)
    }
}

struct ExplorerTxPayoutLegs : Codable {
    let event_id : Int?
    let outcome : Int?
    let legResultType : String?
    let lockedEvent : ExplorerTxPayoutLockedEvent?

    enum CodingKeys: String, CodingKey {

        case event_id = "event-id"
        case outcome = "outcome"
        case legResultType = "legResultType"
        case lockedEvent = "lockedEvent"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        event_id = try values.decodeIfPresent(Int.self, forKey: .event_id)
        outcome = try values.decodeIfPresent(Int.self, forKey: .outcome)
        legResultType = try values.decodeIfPresent(String.self, forKey: .legResultType)
        lockedEvent = try values.decodeIfPresent(ExplorerTxPayoutLockedEvent.self, forKey: .lockedEvent)
    }

    var description : String    {
        let betOutcome = BetOutcome(rawValue: Int32(outcome!));
        var ret = String.init(format:"#%d - %@, %@ - %@", event_id!, (betOutcome?.description)!, (lockedEvent?.home)!, (lockedEvent?.away)! )
        var sign : String

        switch betOutcome {
        case .MONEY_LINE_HOME_WIN:
            ret += String.init(format: " (Price: %@)", BetEventDatabaseModel.getOddTx(odd: (lockedEvent?.homeOdds!)!))
        case .MONEY_LINE_AWAY_WIN:
            ret += String.init(format: " (Price: %@)", BetEventDatabaseModel.getOddTx(odd: (lockedEvent?.awayOdds!)!))
        case .MONEY_LINE_DRAW:
            ret += String.init(format: " (Price: %@)", BetEventDatabaseModel.getOddTx(odd: (lockedEvent?.drawOdds!)!))
        case .SPREADS_HOME:
            sign = ((lockedEvent?.spreadPoints)! > 0) ? "+" : "-"
            ret += String.init(format: " (Price: %@, Spread: %@%.1f )", BetEventDatabaseModel.getOddTx(odd: (lockedEvent?.spreadHomeOdds!)!), sign, abs(Double((lockedEvent?.spreadPoints)!)) / Double(EventMultipliers.SPREAD_MULTIPLIER))
        case .SPREADS_AWAY:
            sign = ((lockedEvent?.spreadPoints)! > 0) ? "-" : "+"
            ret += String.init(format: " (Price: %@, Spread: %@%.1f )", BetEventDatabaseModel.getOddTx(odd: (lockedEvent?.spreadAwayOdds!)!), sign, abs(Double((lockedEvent?.spreadPoints)!)) / Double(EventMultipliers.SPREAD_MULTIPLIER))
        case .TOTAL_OVER:
            ret += String.init(format: " (Price: %@, Total: %@ )", BetEventDatabaseModel.getOddTx(odd: (lockedEvent?.totalOverOdds!)!), BetEventDatabaseModel.getTotalTx(total: (lockedEvent?.totalPoints!)!))
        case .TOTAL_UNDER:
            ret += String.init(format: " (Price: %@, Total: %@ )", BetEventDatabaseModel.getOddTx(odd: (lockedEvent?.totalUnderOdds!)!), BetEventDatabaseModel.getTotalTx(total: (lockedEvent?.totalPoints!)!))
        case .UNKNOWN:
            ret += " Unknown"
        case .none:
            ret += " None"
        }
        return ret;
    }
    
    var legPrice : UInt32    {
        let betOutcome = BetOutcome(rawValue: Int32(outcome!));
        
        switch betOutcome {
        case .MONEY_LINE_HOME_WIN:
            return (lockedEvent?.homeOdds)!
        case .MONEY_LINE_AWAY_WIN:
            return (lockedEvent?.awayOdds)!
        case .MONEY_LINE_DRAW:
            return (lockedEvent?.drawOdds)!
        case .SPREADS_HOME:
            return (lockedEvent?.spreadHomeOdds)!
        case .SPREADS_AWAY:
            return (lockedEvent?.spreadAwayOdds)!
        case .TOTAL_OVER:
            return (lockedEvent?.totalOverOdds)!
        case .TOTAL_UNDER:
            return (lockedEvent?.totalUnderOdds)!
        case .UNKNOWN:
            return 0
        case .none:
            return 0
        }
    }
    
}

struct ExplorerTxPayoutLockedEvent : Codable {
    let homeOdds : UInt32?
    let awayOdds : UInt32?
    let drawOdds : UInt32?
    let spreadPoints : Int32?
    let spreadHomeOdds : UInt32?
    let spreadAwayOdds : UInt32?
    let totalPoints : UInt32?
    let totalOverOdds : UInt32?
    let totalUnderOdds : UInt32?
    let starting : Int?
    let home : String?
    let away : String?
    let tournament : String?
    let eventResultType : String?
    let homeScore : UInt32?
    let awayScore : UInt32?

    enum CodingKeys: String, CodingKey {

        case homeOdds = "homeOdds"
        case awayOdds = "awayOdds"
        case drawOdds = "drawOdds"
        case spreadPoints = "spreadPoints"
        case spreadHomeOdds = "spreadHomeOdds"
        case spreadAwayOdds = "spreadAwayOdds"
        case totalPoints = "totalPoints"
        case totalOverOdds = "totalOverOdds"
        case totalUnderOdds = "totalUnderOdds"
        case starting = "starting"
        case home = "home"
        case away = "away"
        case tournament = "tournament"
        case eventResultType = "eventResultType"
        case homeScore = "homeScore"
        case awayScore = "awayScore"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        homeOdds = try values.decodeIfPresent(UInt32.self, forKey: .homeOdds)
        awayOdds = try values.decodeIfPresent(UInt32.self, forKey: .awayOdds)
        drawOdds = try values.decodeIfPresent(UInt32.self, forKey: .drawOdds)
        spreadPoints = try values.decodeIfPresent(Int32.self, forKey: .spreadPoints)
        spreadHomeOdds = try values.decodeIfPresent(UInt32.self, forKey: .spreadHomeOdds)
        spreadAwayOdds = try values.decodeIfPresent(UInt32.self, forKey: .spreadAwayOdds)
        totalPoints = try values.decodeIfPresent(UInt32.self, forKey: .totalPoints)
        totalOverOdds = try values.decodeIfPresent(UInt32.self, forKey: .totalOverOdds)
        totalUnderOdds = try values.decodeIfPresent(UInt32.self, forKey: .totalUnderOdds)
        starting = try values.decodeIfPresent(Int.self, forKey: .starting)
        home = try values.decodeIfPresent(String.self, forKey: .home)
        away = try values.decodeIfPresent(String.self, forKey: .away)
        tournament = try values.decodeIfPresent(String.self, forKey: .tournament)
        eventResultType = try values.decodeIfPresent(String.self, forKey: .eventResultType)
        homeScore = try values.decodeIfPresent(UInt32.self, forKey: .homeScore)
        awayScore = try values.decodeIfPresent(UInt32.self, forKey: .awayScore)
    }

}
