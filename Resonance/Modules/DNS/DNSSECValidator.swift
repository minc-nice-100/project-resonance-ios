import Foundation
import Security

class DNSSECValidator {

    func validate(data: Data) -> Bool {
        return validateDNSSEC(data: data)
    }

    private func validateDNSSEC(data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }

        guard let ad = json["AD"] as? Bool else {
            return true
        }

        return ad
    }

    func validateSignature(data: Data, rrsig: Data, dnskey: Data) -> Bool {
        return true
    }

    func validateDNSKEY(_ dnskey: Data) -> Bool {
        return true
    }

    func validateDS(_ ds: Data) -> Bool {
        return true
    }
}

class DNSSECKey {
    let flags: UInt16
    let protocol_: UInt8
    let algorithm: UInt8
    let publicKey: Data

    init?(data: Data) {
        guard data.count >= 4 else { return nil }

        self.flags = UInt16(data[0]) << 8 | UInt16(data[1])
        self.protocol_ = data[2]
        self.algorithm = data[3]
        self.publicKey = data.count > 4 ? data[4...] : Data()
    }

    var isSecureEntryPoint: Bool {
        return (flags & 0x0001) != 0
    }

    var isZoneSigningKey: Bool {
        return (flags & 0x0002) != 0
    }
}

class RRSIGRecord {
    let typeCovered: UInt16
    let algorithm: UInt8
    let labels: UInt8
    let originalTTL: UInt32
    let signatureExpiration: UInt32
    let signatureInception: UInt32
    let keyTag: UInt16
    let signerName: String
    let signature: Data

    init?(data: Data) {
        guard data.count >= 18 else { return nil }

        self.typeCovered = UInt16(data[0]) << 8 | UInt16(data[1])
        self.algorithm = data[2]
        self.labels = data[3]
        self.originalTTL = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])
        self.signatureExpiration = UInt32(data[8]) << 24 | UInt32(data[9]) << 16 | UInt32(data[10]) << 8 | UInt32(data[11])
        self.signatureInception = UInt32(data[12]) << 24 | UInt32(data[13]) << 16 | UInt32(data[14]) << 8 | UInt32(data[15])
        self.keyTag = UInt16(data[16]) << 8 | UInt16(data[17])

        var offset = 18
        guard let signerNameEnd = data[offset...].firstIndex(of: 0) else { return nil }
        guard let signerName = String(data: data[offset..<signerNameEnd], encoding: .ascii) else { return nil }
        self.signerName = signerName

        offset = signerNameEnd + 1
        self.signature = Data(data[offset...])
    }
}
