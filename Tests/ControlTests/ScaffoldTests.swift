import Foundation
import XCTest

final class ScaffoldTests: XCTestCase {
    func testBundleMetadataUsesTheControlBundleIdentifier() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlist = packageRoot.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoPlist)
        let metadata = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]

        XCTAssertEqual(metadata?["CFBundleIdentifier"] as? String, "com.control.Control")
        XCTAssertEqual(metadata?["LSUIElement"] as? Bool, true)
    }

    func testLaunchAtLoginUsesNativeServiceManagement() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: packageRoot.appendingPathComponent("Sources/Control/ControlDelegate.swift"),
            encoding: .utf8
        )
        let package = try String(
            contentsOf: packageRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("import ServiceManagement"))
        XCTAssertTrue(source.contains("SMAppService.mainApp"))
        XCTAssertTrue(source.contains("try service.register()"))
        XCTAssertTrue(source.contains("try service.unregister()"))
        XCTAssertTrue(source.contains("Launch at Login"))
        XCTAssertTrue(source.contains(".state"))
        XCTAssertTrue(package.contains(".macOS(.v13)"))
    }

    func testWheelOverlayUsesNonActivatingScreenLevelPresentation() throws {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: packageRoot.appendingPathComponent("Sources/Control/WheelWindowController.swift"),
            encoding: .utf8
        )
        let wheelSource = try String(
            contentsOf: packageRoot.appendingPathComponent("Sources/Control/WheelView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("NSPanel"))
        XCTAssertTrue(source.contains(".nonactivatingPanel"))
        XCTAssertTrue(source.contains(".screenSaver"))
        XCTAssertTrue(source.contains(".moveToActiveSpace"))
        XCTAssertFalse(source.contains(".canJoinAllSpaces"))
        XCTAssertTrue(source.contains("visibleFrame"))
        XCTAssertTrue(source.contains("WheelView.outerRadius"))
        XCTAssertTrue(source.contains("clampedCenter"))
        XCTAssertFalse(wheelSource.contains("localizedName"))
        XCTAssertFalse(wheelSource.contains("label.draw"))
        XCTAssertFalse(wheelSource.contains("bounds.fill()"))
        XCTAssertTrue(wheelSource.contains("drawSegment"))
        XCTAssertTrue(wheelSource.contains("NSGradient"))
        XCTAssertTrue(wheelSource.contains("NSShadow"))
        XCTAssertTrue(wheelSource.contains("segmentGap: CGFloat = 0.025"))
        XCTAssertTrue(wheelSource.contains("lineJoinStyle = .round"))
        XCTAssertTrue(wheelSource.contains("lineCapStyle = .round"))
        XCTAssertTrue(wheelSource.contains("cornerRadius"))
        XCTAssertTrue(wheelSource.contains("path.curve("))
        XCTAssertTrue(source.contains("orderFrontRegardless()"))
        XCTAssertTrue(source.contains("yieldActivation(to: selectedApp)"))
        XCTAssertTrue(source.contains("openApplication(at:"))
        XCTAssertTrue(source.contains("allowsRunningApplicationSubstitution"))
        XCTAssertTrue(source.contains("com.apple.dock"))
        XCTAssertTrue(source.contains("CGEvent"))
        XCTAssertTrue(source.contains("escapeKeyCode: CGKeyCode = 53"))
        XCTAssertTrue(source.contains("attemptsRemaining"))
        XCTAssertTrue(source.contains("mouseTrackingTimer"))
        XCTAssertTrue(source.contains("scheduledTimer"))
        XCTAssertTrue(source.contains(".cghidEventTap"))
        XCTAssertFalse(source.contains("makeKeyAndOrderFront"))
    }
}
