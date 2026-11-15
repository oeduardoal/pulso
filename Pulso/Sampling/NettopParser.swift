import Foundation

enum NettopParser {
    /// Parses the second (delta) sample of `nettop -P -d -L 2 -x -J bytes_in,bytes_out`.
    static func parse(_ output: String) -> [pid_t: Double] {
        let blocks = output.components(separatedBy: ",bytes_in,bytes_out,")
        guard let delta = blocks.last, blocks.count >= 3 else { return [:] }
        var traffic: [pid_t: Double] = [:]
        for line in delta.split(separator: "\n") {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false)
            guard fields.count >= 3, let dot = fields[0].lastIndex(of: "."),
                  let pid = pid_t(fields[0][fields[0].index(after: dot)...]),
                  let received = Double(fields[1]), let sent = Double(fields[2]) else { continue }
            traffic[pid, default: 0] += received + sent
        }
        return traffic
    }
}
