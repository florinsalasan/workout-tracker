# workout_tracker

A workout tracking app with a long list of features that need to be implemented.

## Implemented:

- An overlay where users can track their workouts, adding in as many exercises and sets as they want
- An exercise list where users can add custom exercises, as well as check some information about their personal bests for that exercise
- A workout history tab that details the exercises the user completed along with details of the weight and reps for each set when they are clicked on to expand details of the workout

## TODO:

### Basic Functionality:

- [ ] Add a warning on ending a workout for any sets not marked as complete and have user decide whether to have them deleted or saved as 0 reps.
- [ ] Display a live timer on the overlay handle in place of the 'Active Workout' label
- [ ] Saving workout templates
- [ ] Once templates are implemented, launch workouts from templates with exercises and sets pre-added rather than needing the user to add them all
- [ ] Showcase previous weight x reps for each relevant set inside the overlay to give users an idea of how to progress
- [ ] Implement settings page to choose units of measure, and many more down the line (default to lbs since I'm in NA)
- [ ] Implement some basic analytics features, charts showcasing various metrics for different exercises
- [ ] Implement edit functionality for history of workouts
- [ ] Add many many more exercises to the exercise list
- [ ] Add fuzzy finding search to the exercise list for fun
- [ ] Add calendar view for history page to quickly navigate to different workouts in the past, if multiple on the same day it should filter by the chosen date or scroll the list to that date
- [ ] Rework history tab from including the date on each individual workout to having the workouts grouped by date
- [ ] Implement different themes, such as dark mode and oled dark mode
- [ ] Add ways to sort exercises / filter by tag, ie sorting by recently performed, alphabetical, filtering by body part or isolation vs compound lift etc.
- [ ] In exercises details, rework pb database to have a history of how pbs have improved over time
- [ ] Add a place for users to mark down their height and weight, track body weight maybe in another chart for analytics, maybe match it to scans if they are ever implemented

### Stretch Goals:

- [ ] Body Scan from video of a person spinning in place, as far as I can tell it is technically possible but could be very complex to implement single camera photogrammetry (either in app recording, or choosing a file to scan)
- [ ] Implement ability to import csvs for a workout history from other apps as a migration
