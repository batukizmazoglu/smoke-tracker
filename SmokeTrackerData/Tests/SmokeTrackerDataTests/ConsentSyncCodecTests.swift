import Testing
import Foundation
@testable import SmokeTrackerData

@Suite struct ConsentSyncCodecTests {
    @Test func roundTripTrue() {
        let context = ConsentSyncCodec.encode(trainingDataConsent: true)
        #expect(ConsentSyncCodec.decode(context) == true)
    }

    @Test func roundTripFalse() {
        let context = ConsentSyncCodec.encode(trainingDataConsent: false)
        #expect(ConsentSyncCodec.decode(context) == false)
    }

    @Test func encodesVersionField() {
        let context = ConsentSyncCodec.encode(trainingDataConsent: true)
        #expect((context["consentVersion"] as? Int) == 1)
    }

    @Test func decodeReturnsNilWhenVersionMissing() {
        #expect(ConsentSyncCodec.decode(["trainingDataConsent": true]) == nil)
    }

    @Test func decodeReturnsNilWhenValueWrongType() {
        let context: [String: Any] = ["consentVersion": 1, "trainingDataConsent": "yes"]
        #expect(ConsentSyncCodec.decode(context) == nil)
    }

    @Test func decodeReturnsNilForEmptyContext() {
        #expect(ConsentSyncCodec.decode([:]) == nil)
    }
}
