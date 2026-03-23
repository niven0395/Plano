import Foundation

enum GTACity: String, CaseIterable, Identifiable, Codable {
    case toronto = "Toronto"
    case mississauga = "Mississauga"
    case brampton = "Brampton"
    case markham = "Markham"
    case vaughan = "Vaughan"
    case richmondHill = "Richmond Hill"
    case oakville = "Oakville"
    case burlington = "Burlington"
    case milton = "Milton"
    case ajax = "Ajax"
    case pickering = "Pickering"
    case whitby = "Whitby"
    case oshawa = "Oshawa"

    var id: Self { self }

    var title: String {
        rawValue
    }
}
