import Testing
import Foundation
@testable import STM32Car

/// BLECommand 编码正确性测试。
struct BLECommandTests {

    // MARK: - 方向指令

    @Test func forwardPress() {
        let cmd = BLECommand.directionPress(.forward)
        #expect(cmd.data == Data("ONA\r\n".utf8))
    }

    @Test func backwardPress() {
        let cmd = BLECommand.directionPress(.backward)
        #expect(cmd.data == Data("ONB\r\n".utf8))
    }

    @Test func leftPress() {
        let cmd = BLECommand.directionPress(.left)
        #expect(cmd.data == Data("ONC\r\n".utf8))
    }

    @Test func rightPress() {
        let cmd = BLECommand.directionPress(.right)
        #expect(cmd.data == Data("OND\r\n".utf8))
    }

    @Test func directionRelease() {
        let cmd = BLECommand.directionRelease
        #expect(cmd.data == Data("ONF\r\n".utf8))
    }

    @Test func emergencyStop() {
        let cmd = BLECommand.emergencyStop
        #expect(cmd.data == Data("ONE\r\n".utf8))
    }

    // MARK: - 速度指令

    @Test func speedPress() {
        let cmd = BLECommand.speedPress(5)
        #expect(cmd.data == Data("ON5\r\n".utf8))
    }

    @Test func speedRelease() {
        let cmd = BLECommand.speedRelease(5)
        #expect(cmd.data == Data("ONe\r\n".utf8))
    }

    @Test func speedPressBoundaryLow() {
        let cmd = BLECommand.speedPress(1)
        #expect(cmd.data == Data("ON1\r\n".utf8))
    }

    @Test func speedReleaseBoundaryLow() {
        let cmd = BLECommand.speedRelease(1)
        #expect(cmd.data == Data("ONa\r\n".utf8))
    }

    @Test func speedPressBoundaryHigh() {
        let cmd = BLECommand.speedPress(9)
        #expect(cmd.data == Data("ON9\r\n".utf8))
    }

    @Test func speedReleaseBoundaryHigh() {
        let cmd = BLECommand.speedRelease(9)
        #expect(cmd.data == Data("ONi\r\n".utf8))
    }

    @Test func speedClampBelowRange() {
        let cmd = BLECommand.speedPress(0)
        #expect(cmd.data == Data("ON1\r\n".utf8))
    }

    @Test func speedClampAboveRange() {
        let cmd = BLECommand.speedPress(10)
        #expect(cmd.data == Data("ON9\r\n".utf8))
    }
}
