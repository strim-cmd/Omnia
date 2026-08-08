import XCTest
@testable import OmniaPresentation

final class BubbleTextColorTests: XCTestCase {

    // MARK: Relative luminance

    func testRelativeLuminance_WhiteIsOne() {
        XCTAssertEqual(BubbleTextColor.relativeLuminance(red: 1, green: 1, blue: 1), 1)
    }

    func testRelativeLuminance_BlackIsZero() {
        XCTAssertEqual(BubbleTextColor.relativeLuminance(red: 0, green: 0, blue: 0), 0)
    }

    func testRelativeLuminance_DefaultLightAccent() {
        let luminance = BubbleTextColor.relativeLuminance(
            red: 0,
            green: 122.0 / 255.0,
            blue: 1
        )
        XCTAssertEqual(luminance, 0.2114, accuracy: 0.001)
    }

    func testRelativeLuminance_DefaultDarkAccent() {
        let luminance = BubbleTextColor.relativeLuminance(
            red: 10.0 / 255.0,
            green: 132.0 / 255.0,
            blue: 1
        )
        XCTAssertEqual(luminance, 0.2379, accuracy: 0.001)
    }

    // MARK: Contrast ratio

    func testContrastRatio_WhiteVersusBlackIs21() {
        XCTAssertEqual(BubbleTextColor.contrastRatio(1, 0), 21)
    }

    func testContrastRatio_IsSymmetric() {
        XCTAssertEqual(BubbleTextColor.contrastRatio(0, 1), 21)
    }

    func testContrastRatio_SameColorIsOne() {
        XCTAssertEqual(BubbleTextColor.contrastRatio(0.5, 0.5), 1)
    }

    // MARK: Bubble text choice

    /// The default system accent in light mode is #007AFF: white on it falls
    /// below WCAG AA (≈ 4.0:1), which is the defect the rule fixes (UX audit
    /// V1).
    func testContrast_WhiteOnDefaultLightAccentFailsAA() {
        let luminance = BubbleTextColor.relativeLuminance(
            red: 0,
            green: 122.0 / 255.0,
            blue: 1
        )
        XCTAssertLessThan(BubbleTextColor.contrastRatio(1, luminance), 4.5)
    }

    /// The default system accent in both light and dark mode chooses black
    /// text and meets WCAG AA (UX audit V1).
    func testContrast_DefaultAccentsChooseBlackAndMeetAA() {
        let accents = [
            (red: 0.0, green: 122.0 / 255.0, blue: 1.0),
            (red: 10.0 / 255.0, green: 132.0 / 255.0, blue: 1.0),
        ]
        for accent in accents {
            let luminance = BubbleTextColor.relativeLuminance(
                red: accent.red,
                green: accent.green,
                blue: accent.blue
            )
            XCTAssertEqual(
                BubbleTextColor.contrasting(
                    backgroundRed: accent.red,
                    green: accent.green,
                    blue: accent.blue
                ),
                .black
            )
            XCTAssertGreaterThanOrEqual(
                BubbleTextColor.contrastRatio(0, luminance),
                4.5
            )
        }
    }

    func testContrast_BlackBackgroundChoosesWhite() {
        XCTAssertEqual(
            BubbleTextColor.contrasting(backgroundRed: 0, green: 0, blue: 0),
            .white
        )
    }

    func testContrast_WhiteBackgroundChoosesBlack() {
        XCTAssertEqual(
            BubbleTextColor.contrasting(backgroundRed: 1, green: 1, blue: 1),
            .black
        )
    }

    func testContrast_DarkAccentChoosesWhite() {
        XCTAssertEqual(
            BubbleTextColor.contrasting(
                backgroundRed: 11.0 / 255.0,
                green: 61.0 / 255.0,
                blue: 145.0 / 255.0
            ),
            .white
        )
    }

    func testContrast_MidGrayChoosesBlack() {
        XCTAssertEqual(
            BubbleTextColor.contrasting(backgroundRed: 0.5, green: 0.5, blue: 0.5),
            .black
        )
    }

    func testContrast_ChoosesTheHigherContrastCandidate() {
        let samples: [(red: Double, green: Double, blue: Double)] = [
            (0, 122.0 / 255.0, 1),
            (10.0 / 255.0, 132.0 / 255.0, 1),
            (0, 0, 0),
            (1, 1, 1),
            (0.5, 0.5, 0.5),
            (0.2, 0.4, 0.6),
        ]
        for sample in samples {
            let luminance = BubbleTextColor.relativeLuminance(
                red: sample.red,
                green: sample.green,
                blue: sample.blue
            )
            let chosen = BubbleTextColor.contrasting(
                backgroundRed: sample.red,
                green: sample.green,
                blue: sample.blue
            )
            let expected = BubbleTextColor.contrastRatio(1, luminance)
                >= BubbleTextColor.contrastRatio(0, luminance)
                ? BubbleTextColor.white
                : BubbleTextColor.black
            XCTAssertEqual(chosen, expected)
        }
    }
}
