# Google Maps Integration in Rentra

This document details the integration of Google Maps features into the Rentra application.

## Features Implemented

### 1. Admin Side (Add Property)
- **Google Places Autocomplete**: Allows owners to easily search and select the property address.
- **Interactive Map**: Displays a map where owners can refine the location by dragging a pin.
- **Current Location**: "Use Current Location" button to fetch GPS coordinates.
- **Data Persistence**: Stores `latitude`, `longitude`, and `googleMapAddress` in Firestore.

### 2. User Side (Home Screen)
- **Location Filters**: Horizontal scrolling list of filters including "Live Location" and major cities (Delhi, Bengaluru, Mumbai, etc.).
- **Live Location**: Fetches user's current GPS location to show nearby hostels.
- **City Filters**: Selecting a city displays hostels near that city's center.

### 3. User Side (Search Screen)
- **Location Search**: Users can search for a specific location using Google Places Autocomplete in the filter dialog.
- **Distance Filter**: A slider allows users to set a search radius (1km - 10km) around the selected location.
- **Distance Sorting**: Results are sorted by distance when a location is involved.

### 4. User Side (Detail Screen)
- **Static Map**: Displays the property's location on a lite-mode Google Map.
- **Navigate Button**: Opens Google Maps (external app) with directions to the property.

## Setup & Configuration

### Dependencies used
- `google_maps_flutter`
- `google_places_flutter`
- `geolocator`
- `url_launcher`

### API Keys
The Google Maps API Key is configured in `AndroidManifest.xml` and used in `AddHostelScreen` and `SearchScreen`.

### Permissions
Required permissions added to `AndroidManifest.xml`:
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

## Key Files Modified
- `lib/screens/admin/add_hostel_screen.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/search/search_screen.dart`
- `lib/screens/hotel/hotel_detail_screen.dart`
- `lib/services/firestore_service.dart`
- `lib/models/hostel_model.dart`

## Future Improvements
- Add map clustering for the search results map view (if a map view is added).
- Implement real-time distance calculation in list view cards.
