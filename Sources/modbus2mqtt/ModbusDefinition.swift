//
//  Created by Patrick Stein on 18.03.22.
//

@preconcurrency import Foundation
import SwiftLibModbus
import JLog


public enum MQTTVisibilty:String,Encodable,Decodable,Sendable
{
    case invisible,visible,retained
}

struct ModbusDefinition:Encodable,Sendable
{
    enum ModbusAccess:String,Encodable,Decodable
    {
        case read
        case readwrite
        case write
    }

    enum ModbusValueType:String,Encodable,Decodable
    {
        case bool

        case uint8
        case int8
        case uint16
        case int16
        case uint32
        case int32
        case uint64
        case int64

        case string
        case ipv4address
        case macaddress
    }

    let address:Int
    let length:Int?
    let modbustype:ModbusRegisterType
    let modbusaccess:ModbusAccess
    let endianness:ModbusDeviceEndianness?

    let valuetype:ModbusValueType
    let factor:Decimal?
    let unit:String?

    let mqtt:MQTTVisibilty
    let publishalways:Bool?
    let interval:Double
    let topic:String
    let title:String

    var nextReadDate:Date! = .distantPast
}





extension ModbusDefinition:Decodable
{
    enum CodingKeys: String, CodingKey
    {
        case address,length,modbustype,modbusaccess,endianness,valuetype,factor,unit,mqtt,publishalways,interval,topic,title,nextReadDate
    }

    public init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let address = try? container.decode(Int.self, forKey: .address)
        {
            self.address = address
        }
        else
        {
            let addressString:String = try container.decode(String.self, forKey: .address)
            JLog.debug("addressString: \(addressString)")

            guard let address = addressString.hasPrefix("0x") ? Int(addressString.dropFirst(2),radix: 16) : Int(addressString)
            else
            {
                throw DecodingError.dataCorruptedError(forKey: .address, in: container, debugDescription: "Could not decode string \(addressString) as Int")
            }
            self.address = address
        }
        JLog.debug("address: \(self.address)")

        self.length         = try?  container.decode(Int.self, forKey: .length)
        self.modbustype     = try   container.decode(ModbusRegisterType.self, forKey: .modbustype)
        self.modbusaccess   = try   container.decode(ModbusAccess.self, forKey: .modbusaccess)
        self.endianness     = try?  container.decode(ModbusDeviceEndianness.self, forKey: .endianness)

        self.valuetype      = try   container.decode(ModbusValueType.self, forKey: .valuetype)
        self.factor         = try?  container.decode(Decimal.self, forKey: .factor)
        self.unit           = try?  container.decode(String.self, forKey: .unit)

        self.mqtt           = try   container.decode(MQTTVisibilty.self, forKey: .mqtt)
        self.publishalways  = try?  container.decode(Bool.self, forKey: .publishalways)
        self.interval       = try   container.decode(Double.self, forKey: .interval)
        self.topic          = try   container.decode(String.self, forKey: .topic)
        self.title          = try   container.decode(String.self, forKey: .title)

        self.nextReadDate   = try?  container.decode(Date.self, forKey: .nextReadDate)

        JLog.debug("decoded: \(self)")
    }
}



extension ModbusDefinition
{
    static func read(from url:URL) throws -> [Int:ModbusDefinition]
    {
        let jsonData = try Data(contentsOf: url)
        var modbusDefinitions = try JSONDecoder().decode([ModbusDefinition].self, from: jsonData)
        modbusDefinitions = modbusDefinitions.map{ var mbd = $0; mbd.nextReadDate = .distantPast; return mbd }

        let returnValue = Dictionary(uniqueKeysWithValues: modbusDefinitions.map { ($0.address, $0) })

        Self.modbusDefinitions = returnValue
        return returnValue
    }

    static var modbusDefinitions:[Int:ModbusDefinition]! = nil
}


extension ModbusDefinition
{
    var hasFactor:Bool { self.factor != nil && self.factor! != 0 && self.factor! != 1 }
}

