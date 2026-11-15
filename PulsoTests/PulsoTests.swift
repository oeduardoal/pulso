import Foundation
import Testing

@Suite struct NettopParserTests {
    @Test func readsTheDeltaSampleOnly() {
        let output = """
        ,bytes_in,bytes_out,
        Safari.501,9000000,1000,
        kernel_task.0,5,5,
        ,bytes_in,bytes_out,
        Safari.501,1200,300,
        node.42,10,0,
        Some.App.With.Dots.77,1,1,
        """
        let traffic = NettopParser.parse(output)
        #expect(traffic[501] == 1500)
        #expect(traffic[42] == 10)
        #expect(traffic[77] == 2)
        #expect(traffic[0] == nil)
    }

    @Test func ignoresIncompleteOutput() {
        #expect(NettopParser.parse("").isEmpty)
        #expect(NettopParser.parse(",bytes_in,bytes_out,\nSafari.1,2,3,").isEmpty)
    }
}

@Suite struct MenuBarOrderTests {
    @Test func keepsOrderAndHidesModules() {
        let modules = Pref.menuBarModules(order: "network,cpu", hidden: "disk,battery")
        #expect(modules == [.network, .cpu, .memory, .sensors])
    }

    @Test func ignoresUnknownEntries() {
        #expect(Pref.menuBarModules(order: "gpu,cpu", hidden: "").first == .cpu)
    }
}

@Suite struct SeriesTests {
    @Test func keepsTheLastSixtySamples() {
        var series = Series()
        for value in 0..<100 { series.append(Double(value)) }
        #expect(series.values.count == Series.capacity)
        #expect(series.values.first == 40)
        #expect(series.last == 99)
        #expect(series.peak == 99)
    }
}

@Suite struct CatalogTests {
    /// The test bundle carries the String Catalog, so plural rules can be checked directly.
    @Test func pluralVariants() throws {
        let bundle = Bundle(for: BundleToken.self)
        func lookup(_ key: String, _ language: String, _ count: Int) throws -> String {
            let path = try #require(bundle.path(forResource: language, ofType: "lproj"))
            let format = try #require(Bundle(path: path)).localizedString(forKey: key, value: nil, table: nil)
            return String(format: format, locale: Locale(identifier: language), arguments: [count])
        }
        #expect(try lookup("disk.volumesConnected", "en", 1) == "1 volume connected")
        #expect(try lookup("disk.volumesConnected", "en", 2) == "2 volumes connected")
        #expect(try lookup("disk.volumesConnected", "pt-BR", 2) == "2 volumes conectados")
        #expect(try lookup("settings.updateInterval.seconds", "pt-BR", 1) == "1 segundo")
    }
}

private final class BundleToken {}
