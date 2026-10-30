import APIInquiryCore

enum ProviderLogoMetricsTests {
    static func run(using harness: TestHarness) {
        testEveryProviderHasMeasuredTemplate(using: harness)
        testWordmarkRendersAtTheSurfaceHeight(using: harness)
        testLockupWidthsStayWithinTheChip(using: harness)
    }

    private static func testEveryProviderHasMeasuredTemplate(using harness: TestHarness) {
        for id in ProviderID.allCases {
            guard let template = ProviderLogoMetrics.template(for: id) else {
                harness.expectTrue(false, "\(id.rawValue) has a measured logo template")
                continue
            }
            harness.expectTrue(template.canvasWidth > 0, "\(id.rawValue) canvas width is positive")
            harness.expectTrue(template.canvasHeight > 0, "\(id.rawValue) canvas height is positive")
            harness.expectTrue(template.wordmarkHeight > 0, "\(id.rawValue) wordmark height is positive")
            harness.expectTrue(template.xHeight > 0, "\(id.rawValue) x-height is positive")
            harness.expectTrue(template.xHeight <= template.wordmarkHeight, "\(id.rawValue) x-height fits inside the wordmark")
            harness.expectTrue(
                template.wordmarkHeight <= template.canvasHeight,
                "\(id.rawValue) wordmark fits inside its canvas"
            )
        }
    }

    private static func testWordmarkRendersAtTheSurfaceHeight(using harness: TestHarness) {
        for surface in ProviderLogoSurface.allCases {
            for id in ProviderID.allCases {
                guard let template = ProviderLogoMetrics.template(for: id),
                      let size = ProviderLogoMetrics.size(for: id, on: surface) else {
                    harness.expectTrue(false, "\(id.rawValue) has a size on \(surface.rawValue)")
                    continue
                }
                // Rendered x-height = anchor scaled by how much of the canvas the frame covers.
                let rendered = template.xHeight * (size.height / template.canvasHeight) / template.visualScale
                harness.expectEqual(
                    (rendered * 100).rounded() / 100,
                    (surface.xHeight * 100).rounded() / 100,
                    "\(id.rawValue) x-height renders at \(surface.rawValue) target"
                )
            }
        }
    }

    private static func testLockupWidthsStayWithinTheChip(using harness: TestHarness) {
        for surface in ProviderLogoSurface.allCases {
            for id in ProviderID.allCases {
                guard let size = ProviderLogoMetrics.size(for: id, on: surface) else { continue }
                harness.expectTrue(
                    size.width >= 60 && size.width <= 140,
                    "\(id.rawValue) \(surface.rawValue) lockup width \(Int(size.width))pt stays inside the 40pt-tall chip"
                )
                harness.expectTrue(
                    size.height <= 30,
                    "\(id.rawValue) \(surface.rawValue) lockup height \(Int(size.height))pt leaves chip padding"
                )
            }
        }
    }

    private static func testOpenCodeUsesTheOfficialPixelWordmark(using harness: TestHarness) {
        guard let openCode = ProviderLogoMetrics.template(for: .opencode) else {
            harness.expectTrue(false, "opencode template exists")
            return
        }
        // The official lockup is 1764x505 with a 230px wordmark and a 164px x-height:
        // a pixel-block face whose small letters fill 71% of the ink box.
        harness.expectEqual(openCode.canvasWidth, 1764, "opencode lockup width comes from the official asset")
        harness.expectTrue(
            openCode.xHeight / openCode.wordmarkHeight > 0.65,
            "opencode pixel wordmark keeps its large x-height ratio"
        )
    }

}
