//
//  HomeVC.swift
//  htchhkr-development
//
//  Created by sade on 27/8/18.
//  Copyright © 2018 sade. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import RevealingSplashView
import Firebase

enum AnnotationType {
    case pickup
    case destination
    case driver
}

enum ButtonAction {
    case requestRide
    case getDirectionsToPassenger
    case getDirectionToDestination
    case startTrip
    case endTrip
}

class HomeVC: UIViewController, Alertable  {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var actionBtn: RoundedShadowButton!
    @IBOutlet weak var centerMapBtn: UIButton!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: CircleView!
    @IBOutlet weak var cancelBtn: UIButton!
    
    var delegate: CenterVCDelegate?
    
    var manager: CLLocationManager?
    
    var currentUserId = Auth.auth().currentUser?.uid
    
    var regionRadius: CLLocationDistance = 1000
    
    let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: UIColor.white)
    
    var tableView = UITableView()
    
    var matchingItems:[MKMapItem] = [MKMapItem]()
    
    var route: MKRoute!
    
    var selectedItemPlacemark: MKPlacemark? = nil
    
    var actionForButton: ButtonAction = .requestRide
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        manager = CLLocationManager()
        manager?.delegate = self
        manager?.desiredAccuracy = kCLLocationAccuracyBest
        
        checkLocationAuthStatus()
        
        mapView.delegate = self
        destinationTextField.delegate = self
        
        centerMapOnUserLocation()
        
        DataService.instance.REF_DRIVERS.observe(.value, with: { (snapshot) in
            self.loadDriverAnnotationFromFB()
            
            DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                }
            })
            
        })
        
        cancelBtn.alpha = 0.0
        
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = SplashAnimationType.heartBeat
        revealingSplashView.startAnimation()
        
        UpdateService.instance.observeTrips { (tripDict) in
            if let tripDict = tripDict {
                let pickupCoordinateArray = tripDict["pickupCoordinate"] as! NSArray
                let tripKey = tripDict["passengerKey"] as! String
                let acceptanceStatus = tripDict["tripIsAccepted"] as! Bool
                
                if acceptanceStatus == false {
                    DataService.instance.driverIsAvailable(key: self.currentUserId!, handler: { (available) in
                        if let available = available {
                            if available == true {
                                let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
                                let pickupVC = storyboard.instantiateViewController(withIdentifier: "PickupVC") as? PickupVC
                                pickupVC?.initData(coordinate: CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees), passengerKey: tripKey)
                         
                             
                                self.present(pickupVC!, animated: true, completion: nil)
                            }
                        }
                    })
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DataService.instance.userIsDriver(userKey: currentUserId!, handler:  { (status) in
            if status == true {
                self.buttonForDriver(areHidden: true)
            }
        })
        
        DataService.instance.REF_TRIPS.observe(.childRemoved, with: { (removedTripSnapshot) in
            let removedTripDict = removedTripSnapshot.value as? [String: AnyObject]
            if removedTripDict?["drivedKey"] != nil {
                DataService.instance.REF_DRIVERS.child(removedTripDict?["driverKey"] as! String).updateChildValues(["driverIsOnTrip": false])
            }
            
            DataService.instance.userIsDriver(userKey: self.currentUserId!, handler: { (isDriver) in
                if isDriver == true {
                    //Remove overlays and annotations / hide request ride btn and cansel btn
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                        
                } else {
                    self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.actionBtn.animateButton(shouldLoad: false, withMessage: "REQUEST RIDE")
                        
                    self.destinationTextField.isUserInteractionEnabled = true
                    self.destinationTextField.text = ""
                        
                    // remove all map annotation and overlays
                    self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                    self.centerMapOnUserLocation()
                    }
            })
        })
        
        DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    if let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] {
                        for trip in tripSnapshot {
                            if trip.childSnapshot(forPath: "driverKey").value as? String == self.currentUserId! {
                                let pickupCoordinateArray = trip.childSnapshot(forPath: "pickupCoordinate").value as! NSArray
                                let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                                let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                                
                                self.dropPinFor(placemark: pickupPlacemark)
                                self.searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                                
                                self.setCustomRegion(forAnnotationType: .pickup, withCoordinate: pickupCoordinate)
                                
                                self.actionForButton = .getDirectionsToPassenger
                                self.actionBtn.setTitle("GET DIRECTION", for: .normal)
                                
                                // Fade in the action button for the driver
                                self.buttonForDriver(areHidden: false)
                            }
                        }
                    }
                })
            }
        })
        connectUserAndDriverForTrip()
    }
    
    func checkLocationAuthStatus() {
        if CLLocationManager.authorizationStatus() == .authorizedAlways {
            manager?.startUpdatingLocation()
        } else {
            manager?.requestWhenInUseAuthorization()
            manager?.requestAlwaysAuthorization()
        }
    }
    
    func buttonForDriver(areHidden: Bool) {
        if areHidden {
            self.actionBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            self.actionBtn.isHidden = true
            self.cancelBtn.isHidden = true
            self.centerMapBtn.isHidden = true
        } else {
            self.actionBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.cancelBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
            self.actionBtn.isHidden = false
            self.cancelBtn.isHidden = false
            self.centerMapBtn.isHidden = false
        }
    }
    
    func loadDriverAnnotationFromFB(){
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for driver in driverSnapshot {
                    if driver.hasChild("userIsDriver"){
                        if driver.hasChild("coordinate") {
                            if driver.childSnapshot(forPath: "isPickupModeEnabled").value as? Bool == true {
                                if  let driverDict = driver.value as? Dictionary<String, AnyObject> {
                                    let coordinateArray = driverDict["coordinate"] as! NSArray
                                    let driverCoordinate = CLLocationCoordinate2D(latitude: coordinateArray[0] as! CLLocationDegrees, longitude: coordinateArray[1] as! CLLocationDegrees)
                                    
                                    let annotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driver.key)
                                    
                                    var driverIsVisible: Bool {
                                        return self.mapView.annotations.contains(where: { (annotation) -> Bool in
                                            if let driverAnnotation = annotation as? DriverAnnotation {
                                                if driverAnnotation.key == driver.key {
                                                    driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: driverCoordinate)
                                                    return true
                                                }
                                            }
                                            return false
                                        })
                                    }
                                    
                                    if !driverIsVisible {
                                        self.mapView.addAnnotation(annotation)
                                    }
                                }
                            } else {
                                for annotation in self.mapView.annotations {
                                    if annotation.isKind(of: DriverAnnotation.self) {
                                        if let annotation = annotation as? DriverAnnotation {
                                            if annotation.key == driver.key {
                                                self.mapView.removeAnnotation(annotation)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
        })
        revealingSplashView.heartAttack = true
    }
    
    func connectUserAndDriverForTrip() {
        DataService.instance.userIsDriver(userKey: currentUserId!) { (status) in
            if status == false {
                DataService.instance.REF_TRIPS.child(self.currentUserId!).observe(.value, with: { (tripSnapshot) in
                    let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>
                    
                    if tripDict?["tripIsAccepted"] as? Bool == true {
                        self.removeOverlaysAndAnnotations(forDrivers: false, forPassengers: true)
                        
                        let driverId = tripDict!["driverKey"] as! String
                        
                        let pickupCoordinateArray = tripDict?["pickupCoordinate"] as! NSArray
                        let pickupCoordinate = CLLocationCoordinate2DMake(pickupCoordinateArray[0] as! CLLocationDegrees, pickupCoordinateArray[1] as! CLLocationDegrees)
                        let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                        let pickupMapItem = MKMapItem(placemark: pickupPlacemark)
                        
                        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (driverSnapshot) in
                            if let driverSnapshot = driverSnapshot.children.allObjects as? [DataSnapshot] {
                                for driver in driverSnapshot {
                                    if driver.key == driverId {
                                        let driverCoordinateArray = driver.childSnapshot(forPath: "coordinate").value as! NSArray
                                        let driverCoordinate = CLLocationCoordinate2DMake(driverCoordinateArray[0] as! CLLocationDegrees, driverCoordinateArray[1] as! CLLocationDegrees)
                                        let driverPlasemark = MKPlacemark(coordinate: driverCoordinate)
                                        let driverMapItem = MKMapItem(placemark: driverPlasemark)
                                        
                                        let passengerAnnotation = PassengerAnnotation(coordinate: pickupCoordinate, key: self.currentUserId!)
                                        let driverAnnotation = DriverAnnotation(coordinate: driverCoordinate, withKey: driverId)
                                        
                                        self.searchMapKitForResultsWithPolyline(forOriginMapItem: driverMapItem, withDestinationMapItem: pickupMapItem)
                                        self.actionBtn.animateButton(shouldLoad: false, withMessage: "DRIVER COMING")
                                        self.actionBtn.isUserInteractionEnabled = false
                                    }
                                }
                            }
                        })
                    }
                })
            }
        }
    }
    
    func centerMapOnUserLocation() {
        let coordinateRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, latitudinalMeters: regionRadius * 2, longitudinalMeters: regionRadius * 2)
        mapView.setRegion(coordinateRegion, animated: true)
    }

    @IBAction func actionBtnWasPressed(_ sender: Any) {
        buttonSelector(forAction: actionForButton)
    }
    
    @IBAction func cancelBtnWasPressed(_ sender: Any) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: tripKey!, forDriverKey: driverKey!)
            }
        }
        
        DataService.instance.passengerIsOnTrip(passengerKey: currentUserId!) { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                UpdateService.instance.cancelTrip(withPassengerKey: self.currentUserId!, forDriverKey: driverKey!)
            } else {
                UpdateService.instance.cancelTrip(withPassengerKey: self.currentUserId!, forDriverKey: nil)
            }
        }
        self.actionBtn.isUserInteractionEnabled = true
    }
    
    
    @IBAction func centerMapBtnWasPressed(_ sender: Any) {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value, with: { (snapshot) in
            if let userSnapshot = snapshot.children.allObjects as? [DataSnapshot] {
                for user in userSnapshot {
                    if user.key == self.currentUserId! {
                        if user.hasChild("tripCoordinate") {
                            self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        } else {
                            self.centerMapOnUserLocation()
                            self.centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        }
                    }
                }
            }
        })
        
       // centerMapOnUserLocation()
        //centerMapBtn.fadeTo(alphaValue: 0.0, withDuration: 9.2)
    }
    @IBAction func menuBtnWasPressed(_ sender: Any) {
        delegate?.toggleLeftPanel()
        
    }
    
    func buttonSelector(forAction action: ButtonAction) {
        switch action {
        case .requestRide:
            if destinationTextField.text != "" {
                UpdateService.instance.updateTripsWithCoordinatesUponRequest()
                actionBtn.animateButton(shouldLoad: true, withMessage: nil)
                cancelBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
                
                self.view.endEditing(true)
                destinationTextField.isUserInteractionEnabled = false
            }

        case .getDirectionsToPassenger:
            DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler:  { (isOnTrip, driverKey, tripKey) in
                if isOnTrip == true {
                    DataService.instance.REF_TRIPS.child(tripKey!).observe(.value, with: { (tripSnapshot) in
                        let tripDict = tripSnapshot.value as? Dictionary<String, AnyObject>
                        
                        let pickupCoordinateArray = tripDict?["pickupCoordinate"] as! NSArray
                        let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                        let pickupMapItem = MKMapItem(placemark: MKPlacemark(coordinate: pickupCoordinate))
                        
                        pickupMapItem.name = "Passenger Pickup Point"
                        pickupMapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    })
                }
            })
        case .startTrip:
           print("Sart trip selected")
        case .getDirectionToDestination:
            print("Got directions to destination")
        case .endTrip:
            print("Ended trip!")
        }
    }
}

extension HomeVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthStatus()
        if status == .authorizedAlways {
            
            mapView.showsUserLocation = true
            mapView.userTrackingMode = .follow
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler: { (isOnTrip, driverKey, passengerKey) in
            if isOnTrip == true {
                if region.identifier == "pickup" {
                    self.actionBtn.setTitle("START TRIP", for: .normal)
                    print("Driver entered pickup region!")
                } else  if region.identifier == "destination" {
                    self.cancelBtn.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    self.cancelBtn.isHidden = true
                    self.actionBtn.setTitle("END TRIP", for: .normal)
                }
            }
        })
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        DataService.instance.driverIsOnTrip(driverKey: currentUserId!, handler:  { (isOnTrip, driverKey, tripKey) in
            if isOnTrip == true {
                if region.identifier == "pickup" {
                    //call an action on the button that will load directions to passenger pickup
                    print("Driver exited pickup region!")
                    self.actionBtn.setTitle("GET DIRECTIONS", for: .normal)
                } else if region.identifier == "destination" {
                    // call an action on the button that will load directions to destination
                    self.actionBtn.setTitle("GET DIRECTION", for: .normal)
                }
            }
        })
    }
}

extension HomeVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        UpdateService.instance.updateUserLocation(withCoordinate: userLocation.coordinate)
        UpdateService.instance.updateDriverLocation(withCoordinate: userLocation.coordinate)
        
        DataService.instance.userIsDriver(userKey: currentUserId!) { (isDriver) in
            if isDriver == true {
                DataService.instance.driverIsOnTrip(driverKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else {
                        self.centerMapOnUserLocation()
                    }
                })
            } else {
                DataService.instance.passengerIsOnTrip(passengerKey: self.currentUserId!, handler: { (isOnTrip, driverKey, tripKey) in
                    if isOnTrip == true {
                        self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: true, withKey: driverKey)
                    } else{
                        self.centerMapOnUserLocation()
                    }
                })
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DriverAnnotation {
            let identifier = "driver"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.image = UIImage(named: "driverAnnotation")
            return view
        } else if let annotation = annotation as? PassengerAnnotation {
            let indentifier = "passenger"
            var view: MKAnnotationView
            view = MKAnnotationView(annotation: annotation, reuseIdentifier: indentifier)
            view.image  = UIImage(named: "currentLocationAnnotation")
            return view
            
        } else if let annotation = annotation as? MKPointAnnotation {
            let indentifier = "destination"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: indentifier)
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: indentifier)
            } else {
                annotationView?.annotation = annotation
            }
            annotationView?.image = UIImage(named: "destinationAnnotation")
            return annotationView
        }
        return nil
    }
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapBtn.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRenderer = MKPolylineRenderer(overlay: self.route.polyline)
        lineRenderer.strokeColor = UIColor(displayP3Red: 216/255, green: 71/255, blue: 30/255, alpha: 0.75)
        lineRenderer.lineWidth = 3
        
        shouldPresentLoadingView(false)
        
        return lineRenderer
    }
    
    func performSearch(){
        matchingItems.removeAll()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = destinationTextField.text
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        
        search.start { (response, error) in
            if error != nil {
               self.showAlert("An error occurred, please try again.")
            } else if response!.mapItems.count == 0 {
                self.showAlert("No results! Please search again for a different location.")
            } else {
                for mapItem in response!.mapItems {
                    self.matchingItems.append(mapItem as MKMapItem)
                    self.tableView.reloadData()
                    self.shouldPresentLoadingView(false)
                }
            }
        }
    }
    
    func dropPinFor(placemark: MKPlacemark) {
        selectedItemPlacemark = placemark
        
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = placemark.coordinate
        mapView.addAnnotation(annotation)
    }
    
    func searchMapKitForResultsWithPolyline(forOriginMapItem originalMapItem: MKMapItem?, withDestinationMapItem destinationMapItem: MKMapItem) {
        let request = MKDirections.Request()
        
        if originalMapItem == nil {
            request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originalMapItem
        }
        
        request.destination = destinationMapItem
        request.transportType = MKDirectionsTransportType.automobile
        request.requestsAlternateRoutes = true
        
        let direction = MKDirections(request: request)
        
        direction.calculate { (response, error) in
            guard let response = response else {
                self.showAlert(error.debugDescription)
                return
            }
            self.route = response.routes[0]
            
            if self.mapView.overlays.count == 0 {
                 self.mapView.addOverlay(self.route.polyline)
            }
            
            self.zoom(toFitAnnotationFromMapView: self.mapView, forActiveTripWithDriver: false, withKey: nil)
            
            let delegate = AppDelegate.getAppDelegate()
            delegate.window?.rootViewController?.shouldPresentLoadingView(false)
        }
        
    }
    
    func zoom(toFitAnnotationFromMapView mapView: MKMapView, forActiveTripWithDriver: Bool, withKey key: String?){
        if mapView.annotations.count == 0 {
            return
        }
        
        var topLeftCoordinate = CLLocationCoordinate2D(latitude: -90, longitude: 180)
        var bottomRightCoordinate = CLLocationCoordinate2D(latitude: 90, longitude: -180)
        
        if forActiveTripWithDriver {
            for annotation in mapView.annotations {
                if let annotation = annotation as? DriverAnnotation {
                    if annotation.key == key {
                        topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                        topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                        bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                        bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                    }
                } else {
                    topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
                    topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
                    bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
                    bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
                }
            }
        }
        
        for annotation in mapView.annotations where !annotation.isKind(of: DriverAnnotation.self) {
            topLeftCoordinate.longitude = fmin(topLeftCoordinate.longitude, annotation.coordinate.longitude)
            topLeftCoordinate.latitude = fmax(topLeftCoordinate.latitude, annotation.coordinate.latitude)
            bottomRightCoordinate.longitude = fmax(bottomRightCoordinate.longitude, annotation.coordinate.longitude)
            bottomRightCoordinate.latitude = fmin(bottomRightCoordinate.latitude, annotation.coordinate.latitude)
        }
        
        var region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(topLeftCoordinate.latitude - (topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 0.5, topLeftCoordinate.longitude + (bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 0.5), span: MKCoordinateSpan(latitudeDelta: fabs(topLeftCoordinate.latitude - bottomRightCoordinate.latitude) * 2.0, longitudeDelta: fabs(bottomRightCoordinate.longitude - topLeftCoordinate.longitude) * 2.0))
        
        region = mapView.regionThatFits(region)
        mapView.setRegion(region, animated: true)
    }
    
    func removeOverlaysAndAnnotations(forDrivers: Bool?, forPassengers: Bool?) {
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            }
            
            if forPassengers! {
                if let annotation = annotation as? PassengerAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
            
            if forDrivers! {
                if let annotation = annotation as? DriverAnnotation {
                    mapView.removeAnnotation(annotation)
                }
            }
        }
        for overlay in mapView.overlays {
            if overlay is MKPolyline {
                mapView.removeOverlay(overlay)
            }
        }
    }
    
    func setCustomRegion(forAnnotationType type: AnnotationType, withCoordinate coordinate: CLLocationCoordinate2D) {
        if type == .pickup {
            let pickupRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: "pickup")
            manager?.startMonitoring(for: pickupRegion)
        } else if type == .destination {
            let destinationRegion = CLCircularRegion(center: coordinate, radius: 100, identifier: "destination")
            manager?.startMonitoring(for: destinationRegion)
        }
    }
}
extension HomeVC: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        tableView.frame = CGRect(x: 20, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 170)
        tableView.layer.cornerRadius = 5.0
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "locationCell")
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.tag = 18
        tableView.rowHeight = 60
        view.addSubview(tableView)
        animateTableView(shouldShow: true)
        
        UIView.animate(withDuration: 0.2) {
            self.destinationCircle.backgroundColor = UIColor.red
            self.destinationCircle.borderColor = UIColor.init(red: 199/255, green: 0/255, blue: 0/255, alpha: 1.0)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == destinationTextField {
            performSearch()
            shouldPresentLoadingView(true)
            view.endEditing(true)
        }
        return true
    }
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == destinationTextField {
            if destinationTextField.text == "" {
                UIView.animate(withDuration: 0.2) {
                    self.destinationCircle.backgroundColor = UIColor.lightGray
                    self.destinationCircle.borderColor = UIColor.darkGray
                }
            }
        }
    }
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        matchingItems = []
        tableView.reloadData()
        
        DataService.instance.REF_USERS.child(currentUserId!).child("tripCoordinate").removeValue()
        mapView.removeOverlays(mapView.overlays)
        for annotation in mapView.annotations {
            if let annotation = annotation as? MKPointAnnotation {
                mapView.removeAnnotation(annotation)
            } else if annotation.isKind(of: PassengerAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        centerMapOnUserLocation()
        return true
    }
    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2) {
                self.tableView.frame = CGRect(x: 20, y: 170, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: self.view.frame.height, width: self.view.frame.width - 40, height: self.view.frame.height - 170)
            }) { (finished) in
                for subview in self.view.subviews {
                    if subview.tag == 18 {
                        subview.removeFromSuperview()
                    }
                }
            }
        }
    }
}

extension HomeVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")
        let mapItem = matchingItems[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title
        return cell
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        shouldPresentLoadingView(true)
        
        let passengerCoordinate = manager?.location?.coordinate
        
        let passengerAnnotation = PassengerAnnotation(coordinate: passengerCoordinate!, key: currentUserId!)
        mapView.addAnnotation(passengerAnnotation)
        
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text
        
        let selectedMapItem = matchingItems[indexPath.row]
        
        DataService.instance.REF_USERS.child(currentUserId!).updateChildValues(["tripCoordinate": [selectedMapItem.placemark.coordinate.latitude, selectedMapItem.placemark.coordinate.longitude]])
        
        dropPinFor(placemark: selectedMapItem.placemark)
        
        searchMapKitForResultsWithPolyline(forOriginMapItem: nil, withDestinationMapItem: selectedMapItem )
        
        animateTableView(shouldShow: false)
        print("selected!!!")
    }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            animateTableView(shouldShow: false)
        }
        
    }
}
