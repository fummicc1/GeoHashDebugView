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
    @State var bitsLength: Int = 10
    @State private var region = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 360, longitudeDelta: 360)
        )
    )
    
    var bounds: [[CLLocationCoordinate2D]] {
        GeoHash.getBounds(with: .exact(digits: bitsLength)).map {
            $0.map { coord in
                CLLocationCoordinate2D(
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
            }
        }
    }
    
    var body: some View {
        Map(position: $region) {
            ForEach(bounds) { bound in
                MapPolyline(coordinates: bound)
                    .stroke(Color.blue, lineWidth: 1)
                Annotation(
                    coordinate: getCenter(in: bound),
                    content: {
                        Text(
                            GeoHash(
                                latitude: getCenter(in: bound).latitude,
                                longitude: getCenter(in: bound).longitude
                            ).geoHash
                        )
                    }
                ) {
                    Text(
                        GeoHash(
                            latitude: getCenter(in: bound).latitude,
                            longitude: getCenter(in: bound).longitude
                        ).binary
                    )
                }
            }
        }
    }
    
    private func getCenter(in bound: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (bound[1].latitude + bound[2].latitude) / 2,
            longitude: (bound[1].longitude + bound[0].longitude) / 2
        )
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
