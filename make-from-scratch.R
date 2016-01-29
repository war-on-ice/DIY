
install.from.github <- function () {
  
  install.packages("devtools")
  
  library(devtools)
  install_github ("war-on-ice/nhlscrapr")
  install_github ("war-on-ice/warbase")
  
}



library(nhlscrapr)
library(warbase)

## If necessary, download everything; then let nhlscrapr do its thing. This concludes the refinement of the nhlscrapr stuff.
## This will take overnight if it hasn't been done yet.

games.grabbed <- compile.all.games(wait=0, 
                                   roster.dropin=rosterprefab,
                                   ## Want to use the existing games table? Uncomment this one.
                                   new.game.table=filter (gamesstart, season >= 20072008),
                                   ## new.game.table=filter (gamesstart, season >= 20132014),
                                   reload.games=TRUE)

make.common()
load("common-data/woi-common.RData")

#load ("source-data/nhlscrapr-core.RData")
#seasons <- unique(games$season)

#GamesGrabbedFull <- slice(gamestest, match(games.grabbed, paste0(gamestest$season, gamestest$gcode))) %>% 
#  select (season, gcode, date)

##date.set <- unique(games$date[match(games.grabbed, paste0(games$season, games$gcode))])

for (season in seasons[seasons <= 20132014]) prep.season (substr(season,1,4))
for (season in seasons[seasons >= 20142015]) prep.season.sportsnet (substr(season,1,4))

## Bind Sportsnet first.
for (ss in seasons[seasons <= 20132014]) try (merge.locs(ss))
for (ss in seasons[seasons >= 20142015]) try (merge.locs.sportsnet(ss))
      
for (ss in seasons) impute.shot.locs(ss)

## Make the distance adjustments for each season given the coordinates we just established.
create.adjusted.distance()
for (ss in seasons) try(update.adjusted.distance(ss))

##make.hextally (seasons, connect.sqldb2())
## At this point, everything's in place to make the individual game files.
make.game.files()

make.collective.coplay.files ()

replace.tc.all ()



## And we're done!


