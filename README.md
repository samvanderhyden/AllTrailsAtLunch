#  AllTrails take home challenge

Hi AllTrails team! Here is my restaurant finding app. Thanks for taking a look!

## Overview

I broke the home screen into 3 main view controllers:

- MapViewController: Displays nearby results on a map
- ListViewController: Displays search results and nearby results as a list
- RootViewController: Manages the above content view controllers and the search bar.

I used an MVVM style architecture, so there is a corresponding view model for each view controller above, and an additional view model for the search bar.
For dependencies, I've demonstrated how I would abstract the API interactions into a "service" object (PlaceSearchService), and pass that into the view model for use. A concrete implementation of the service "GooglePlaceSearchService" interacts with the google places API.

View models in this demo hold all the app logic, and push state to the view controllers for rendering. View models also take events from the UI, modify internal state / interact with dependencies, and push updates back to the UI. I've found this pattern to be effective and have enough separation to allow for pretty good testing of app logic. I've demonstrated dependency mocking and view model testing in `RootViewModelTests`. Additionally, when you define data flow in this "unidirectional" way, it makes the app easier to understand and debug.

## With more time ...

There is a ton left to do to make this a complete app. Some things I've skipped over in the interest of time:

- Restaurant detail screen implementation. I spent all my time on the root screens, and didn't get to this one.
- UI Polish. I didn't take time to polish the UI, add animations, smooth out transitions, etc ... Also the loading, empty, and error states could be improved.
- A better search. I used the place text search, but using place autocomplete would probably be better fit. Place auto complete would allow the user to search locations, and could then be integrated into the map, similar to how the AllTrails app works now. I think this would be a better experience. The challenge here is that autocomplete doesn't return locations, so it would require hitting the place detail api upon autocomplete selection.
- Search the current map area. I didn't get to this either, but would be table-stakes to add for a real app.
- Pagination in list view. The places API paginates with page tokens. Adding support for paginating while scrolling the list view would be an expected feature.
- More Tests: I've demonstrated how I would test the view models by including a few tests for `RootViewModel`, but I would add tests for all view models in a production app, hopefully exercising most input conditions and covering most outputs.

Additionally, a production app would need the following:
- Dark mode support
- Localization (I've make a note of this in most places where it's needed)
- Accessibility support. I've included support for dynamic type in the list view, but we'd want to add voice over support as well.
- Right to left UI rendering, if we are shipping to locale's where that is supported.
- UI state restoration





