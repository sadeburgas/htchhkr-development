//
//  UpdateService.swift
//  htchhkr-development
//
//  Created by sade on 9/10/18.
//  Copyright © 2018 sade. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import Firebase

class UpdateService {
    static var instance = UpdateService()
    
    func updateUserLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == Auth.auth().currentUser?.uid {
                        DataService.instance.REF_USERS.child(user.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                    }
                }
            }
        })
    }
    
    func updateDriverLocation(withCoordinate coordinate: CLLocationCoordinate2D) {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.key == Auth.auth().currentUser?.uid {
                        if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                            DataService.instance.REF_DRIVERS.child(driver.key).updateChildValues(["coordinate": [coordinate.latitude, coordinate.longitude]])
                        }
                    }
                }
            }
        })
    }
    
    func observeTrips(handler: @escaping(_ coordinateDic: Dictionary<String, AnyObject>?) -> Void) {
        DataService.instance.REF_TRIPS.observe(.value, with: { (snapshot) in
            if let tripSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for trip in tripSnapshot {
                    if trip.hasChild("passengerKey") && trip.hasChild("tripIsAccepted") {
                        if let tripDict = trip.value as? Dictionary<String, AnyObject> {
                            handler(tripDict)
                        }
                    }
                }
            }
        })
    }
    
    func updateTripsWithCoordinatesUponRequest() {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == Auth.auth().currentUser?.uid {
                        if !user.hasChild("userIsDriver") {
                            if let userDict = user.value as? Dictionary<String, Any> {
                                let pickupArray = userDict["coordinate"] as! NSArray
                                let destinationArray = userDict["tripCoordinate"] as! NSArray
                                
                                DataService.instance.REF_TRIPS.child(user.key).updateChildValues(["pickupCoordinate": [pickupArray[0], pickupArray[1]], "destinationCoordinate": [destinationArray[0], destinationArray[1]], "passengerKey": user.key, "tripIsAccepted": false])


                            }
                        }
                    }
                }
            }
        })
    }
    

    func acceptTript(withPassengerKey passengerKey: String, forDriverKey driverKey:String) {
        DataService.instance.REF_TRIPS.child(passengerKey).updateChildValues(["driverKey": driverKey, "tripIsAccepted": true])
        DataService.instance.REF_DRIVERS.child(driverKey).updateChildValues(["driverInOnTrip": true])
    }
    func calselTripPassengerKey(withPassengerKey passengerKey: String, forDriverKey driverKey: String) {
        DataService.instance.REF_TRIPS.child(passengerKey).removeValue()
        DataService.instance.REF_USERS.child(passengerKey).child("tripCoordinate").removeValue()
        DataService.instance.REF_DRIVERS.child(driverKey).updateChildValues(["driverTrip": false])
    }
}
