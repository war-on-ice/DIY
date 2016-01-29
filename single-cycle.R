
## Routines for updating the underlying database.
## ACT, last draft: 2015-10-15

minutes <- as.numeric(substr(Sys.time(), 15,16))
hours <- as.numeric(substr(Sys.time(), 12,13))
##hours <- 8

library(nhlscrapr)

## Scrape NHL here. If it was 8:00 GMT, redo the games from the last 3 days.

if (hours == 8) {  ##  || minutes < 2
    games.grabbed <- compile.all.games(wait=0, date.check=TRUE, override=0:3)
} else {
    games.grabbed <- compile.all.games(wait=0)  ##, date.check=TRUE)
}

source ("woi-makedata.R")


game.to.s3 <- function (seasongcode) {
    system (paste0("aws s3 cp common-data/games/",seasongcode,".RData s3://yoursite.net/games/",seasongcode,".RData"))
    return(TRUE)
}
scrapr.to.s3 <- function (season) {
    system (paste0("aws s3 cp source-data/nhlscrapr-",season,".RData s3://yoursite.net/nhlscrapr-",season,".RData"))
    return(TRUE)
}
common.to.s3 <- function () {
    system (paste0("aws s3 cp source-data/nhlscrapr-core.RData s3://yoursite.net/nhlscrapr-core.RData"))
    system (paste0("aws s3 cp common-data/woi-common.RData s3://yoursite.net/woi-common.RData"))
    system (paste0("aws s3 cp common-data/gamestoday.html s3://yoursite.net/gamestoday.html"))
    return(TRUE)
}
upload <- common.to.s3()

common.to.sql <- function (con=connect.sqldb()) {
    dbWriteTable(conn = con, name = "gamestest", value = gamestest, overwrite=TRUE)
    dbWriteTable(conn = con, name = "rosterunique", value = roster.unique %>% as.data.frame, overwrite=TRUE)
    dbWriteTable(conn = con, name = "rostermaster", value = roster.master %>% as.data.frame, overwrite=TRUE)
    dbDisconnect (con)
}
upload <- common.to.sql()


fix.gaps <- function (db = connect.sqldb()) {

    statement <- paste0('SELECT DISTINCT Team FROM playerseason WHERE season = 20152016')
    preprimer <- dbSendQuery(db, statement)
    primer <- fetch(preprimer, n = -1)
    
    getteams <- setdiff(teams[!(teams %in% c("ATL","PHX"))], primer$Team)
    message ("Team Gaps: ", paste(getteams, collapse=","))
    
    if (length(getteams) > 0) compress.players.sql (last(seasons), tms=getteams)

}


## games.grabbed = 2015201620001:2015201620017
if (length(games.grabbed) > 0) {

    ## Get the Sportsnet data to add to it.
    date.set <- unique(gamestest$date[match(games.grabbed,
                                            paste0(gamestest$season,
                                                   gamestest$gcode))])

    try(add.dayrange.sportsnet (date.set))
    try(merge.locs.sportsnet(last(seasons)))

    ##if (minutes < 2)
    impute.shot.locs(last(seasons))
    try(update.adjusted.distance(last(seasons)))
    
    try(make.game.files (use.gameids=TRUE, gameids=games.grabbed))

    ## copy game files to the S3 server.
    ## upload <- sapply (games.grabbed, game.to.s3)
    ## upload <- sapply (unique(substr(games.grabbed,1,8)), scrapr.to.s3)
    
    ## Did any games just finish?
    try(augment.collective.coplay())
    
    ## Add games to server.
    we.did.this.on.the.site <- function () {
      subtable <- gamestest[match(games.grabbed, paste0(gamestest$season, gamestest$gcode)),]
      reduced.games <- filter(subtable, status == 3)

      if (hours == 8) { 
        
          gms <- paste0(reduced.games$season, reduced.games$gcode)
          replace.master.database (gms, con=connect.sqldb())
          compress.players.sql (last(seasons)) ##, tms=unique(c(reduced.games$hometeam, reduced.games$awayteam)))
  
          update.hextally (last(seasons), connect.sqldb())

      } else if (nrow(reduced.games) > 0) {
          
          create.master.database (augment=TRUE, con=connect.sqldb())
          compress.players.sql (last(seasons), tms=unique(c(reduced.games$hometeam, reduced.games$awayteam)))
        
      }
  
    ## Check for missing teams.
    ## fix.gaps ()
    }  
    
} else {message ("Pausing for 3 minutes"); Sys.sleep(3*60)}

message("single-cycle: Compilation done")

## if (hours == 8) Sys.sleep(6*3600)


## 


## grand.data %>% filter (etype %in% c("GOAL","SHOT","MISS","BLOCK")) %>% group_by(gcode) %>% summarise (na1=is.na(newxc))
