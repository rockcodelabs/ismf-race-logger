1. doesnt work http://localhost:3005/admin/competitions/96/races/1002
Dry::Struct::Error in Web::Controllers::Admin::RacesController#show
[Structs::Athlete.new] "AZE" (String) has invalid type for :country violates constraints (included_in?(["AND", "ARG", "AUS", "AUT", "BEL", "BGR", "BIH", "CAN", "CHE", "CHN", "HRV", "CZE", "ESP", "FIN", "FRA", "GBR", "DEU", "GRC", "HUN", "IND", "IRN", "ISR", "ITA", "JPN", "KAZ", "KOR", "LIE", "LTU", "MDA", "MKD", "NLD", "NOR", "NZL", "POL", "PRT", "ROU", "ZAF", "RUS", "SVN", "SRB", "CHE", "SVK", "SWE", "TUR", "UKR", "USA"], "AZE") failed)


2. different menus per role
3. http://localhost:3005/admin/race_types/86/location_templates
Dry::Struct::Error in Web::Controllers::Admin::RaceTypes::LocationTemplatesController#index
[Structs::RaceTypeLocationTemplate.new] "start" (String) has invalid type for :course_segment violates constraints (included_in?(["uphill1", "uphill2", "uphill3", "transition_1to2", "transition_2to1", "descent", "footpart", "start_area", "finish_area"], "start") failed)

4. ✅ seeds for race location templates and race locations - 3,042 race locations created from templates (13 per Sprint, 13 per Individual, 9 per Mixed Relay, 7 per Vertical, 8 per Team)
5. on desktop I cannot change profile
6. in menu link to reports and to report!
7. competitions should be ordered so top the next and latest
8. sprint besides qualifications should be closed after 5min since start if it wasn't manually, qualifications after an hour
9. ✅ in seeds do not add race_participants besides first stage(qualifications) or in boi taull add to current race - Seeds work correctly with all participants
10. ✅ where are penalties - Created db/seeds/penalties.rb with all ISMF penalty codes (A-F categories, 52 penalties across 6 categories A-F)