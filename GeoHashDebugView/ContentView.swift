//
//  ContentView.swift
//  GeoHashDebugView
//
//  Created by Fumiya Tanaka on 2024/11/16.
//

import SwiftUI
import MapKit
import CoreLocation
import GeoHashFramework

struct ContentView: View {
    
    @State var bitsLength: Int = 5
    var bounds: [[CLLocationCoordinate2D]] {
        GeoHash.getBounds(with: .exact(digits: bitsLength)).map {
            $0.map {
                CLLocationCoordinate2D(
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            }
        }
    }
    
    var body: some View {
        Map{
            ForEach(bounds) { bound in
                Group {
                    MapPolyline(
                        coordinates: [
                            bound[0],
                            bound[1]
                        ]
                    )
                    MapPolyline(
                        coordinates: [
                            bound[1],
                            bound[2]
                        ]
                    )
                    MapPolyline(
                        coordinates: [
                            bound[2],
                            bound[3]
                        ]
                    )
                    MapPolyline(
                        coordinates: [
                            bound[3],
                            bound[0]
                        ]
                    )
                }
                .stroke(.green, style: .init(lineWidth: 4))
            }
        }
    }
}

extension Array: @retroactive Identifiable where Element: Identifiable<String> {
    public var id: String {
        map { $0.id }.joined(separator: "|")
    }
}

extension CLLocationCoordinate2D: @retroactive Identifiable {
    public var id: String {
        "\(latitude),\(longitude)"
    }
}

#Preview {
    ContentView()
}
