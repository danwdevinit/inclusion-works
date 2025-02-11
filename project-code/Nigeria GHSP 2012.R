##TODO - Overall prevalence rate

required.packages <- c("reshape2","ggplot2","data.table","foreign")
lapply(required.packages, require, character.only=T)

setwd("G:/My Drive/Work/GitHub/inclusion-works/")


###DATA INPUT###

#Pull post-harvest household roster, section 3a (employment) and section 4a (health)
ghsp.hhr <- read.spss("project-data/NGA_2012_GHSP-W2_v02_M_SPSS/Post Harvest Wave 2/Household/sect1_harvestw2.sav", to.data.frame=T)
names(ghsp.hhr) <- attributes(ghsp.hhr)[4]$variable.labels
ghsp.employ <- read.spss("project-data/NGA_2012_GHSP-W2_v02_M_SPSS/Post Harvest Wave 2/Household/sect3a_harvestw2.sav", to.data.frame=T)
names(ghsp.employ) <- attributes(ghsp.employ)[4]$variable.labels
names(ghsp.employ)[43:66] <- paste(names(ghsp.employ)[43:66],"JOB 2")
ghsp.health <- read.spss("project-data/NGA_2012_GHSP-W2_v02_M_SPSS/Post Harvest Wave 2/Household/sect4a_harvestw2.sav", to.data.frame=T)
names(ghsp.health) <- attributes(ghsp.health)[4]$variable.labels
ghsp.hha <- read.spss("project-data/NGA_2012_GHSP-W2_v02_M_SPSS/Post Harvest Wave 2/Household/secta_harvestw2.sav", to.data.frame=T)

ghsp.hha <- ghsp.hha[,c(1,8)]
names(ghsp.hha) <- c("HOUSEHOLD IDENTIFICATION","SAMPLE.WEIGHT")

###TRANSFORMATIONS###

#Merge and convert to data.table
ghsp.health <- merge(ghsp.hhr,ghsp.health, by.x=c("HOUSEHOLD IDENTIFICATION","LINE NO."),by.y=c("HOUSEHOLD IDENTIFICATION","INDIVIDUAL ID"))
ghsp.health <- as.data.table(ghsp.health)
ghsp.health.employ <- merge(ghsp.health,ghsp.employ,by.x=c("HOUSEHOLD IDENTIFICATION","LINE NO."),by.y=c("HOUSEHOLD IDENTIFICATION","INDIVIDUAL ID"))

#Create age groups of 5 year intervals
ghsp.health.employ$age.group <- ceiling(ghsp.health.employ$`AGE IN COMPLETED YEARS`/5)

#Create employment indicator - this hierachical.. may need to discuss what terms
ghsp.health.employ$employment <- "unemployed"
ghsp.health.employ$employment[which(ghsp.health.employ[,157]=="YES")] <- "employed household farm"
ghsp.health.employ$employment[which(ghsp.health.employ[,158]=="YES")] <- "self employed"
ghsp.health.employ$employment[which(ghsp.health.employ[,156]=="YES")] <- "employed 3rd party"
ghsp.health.employ$employment[which(is.na(ghsp.health.employ[,159]))] <- NA

##Define employed indicator as everything but unemployment and NA
ghsp.health.employ$employed <- "unemployed"
ghsp.health.employ$employed[ghsp.health.employ$employment != "unemployed" | is.na(ghsp.health.employ$employment)] <- "employed"
ghsp.health.employ$employed[is.na(ghsp.health.employ$employment)] <- NA

#Join weights
ghsp.health.employ <- merge(ghsp.health.employ,ghsp.hha, by = "HOUSEHOLD IDENTIFICATION")
ghsp.health.employ <- ghsp.health.employ[which(!is.na(ghsp.health.employ$SAMPLE.WEIGHT))]

#Separate two sets of impairment questions - EMPLOYED INDICATOR
ghsp.wg.cut <- ghsp.health.employ[,c(3:6,8,111,113,115,117,119,121,228,230,231)]
ghsp.other.cut <- ghsp.health.employ[,c(3:6,8,106:110,228,230,231)]
names(ghsp.wg.cut)[13] <- "employment"
names(ghsp.other.cut)[12] <- "employment"

##Separate two sets of impairment questions - EMPLOYMENT INDICATOR
#ghsp.wg.cut <- ghsp.health.employ[,c(8,111,113,115,117,119,121,228,229)]
#ghsp.other.cut <- ghsp.health.employ[,c(8,106:110,228,229)]

#Replace "CANNOT SEE" and "CANNOT HEAR" responses with "CANNOT DO"
levels(ghsp.wg.cut$`DO YOU HAVE DIFFICULTY SEEING, EVEN IF YOU ARE WEARING GLASSES?`)[match("CANNOT SEE", levels(ghsp.wg.cut$`DO YOU HAVE DIFFICULTY SEEING, EVEN IF YOU ARE WEARING GLASSES?`))] <- "CANNOT DO"
levels(ghsp.wg.cut$`DO YOU HAVE DIFFICULTY HEARING, EVEN IF YOU ARE WEARING A HEARING AID?`)[match("CANNOT HEAR", levels(ghsp.wg.cut$`DO YOU HAVE DIFFICULTY HEARING, EVEN IF YOU ARE WEARING A HEARING AID?`))] <- "CANNOT DO"

#Create "Disabled/Not disabled/NA" indicator based on WG criteria
ghsp.wg.cut$disabled <- "Not disabled"
ghsp.wg.cut[which(rowSums(ghsp.wg.cut=="CANNOT DO"|ghsp.wg.cut=="YES, A LOT",na.rm=T)>0L)]$disabled <- "Disabled"
ghsp.wg.cut[which(rowSums(is.na(ghsp.wg.cut),na.rm=T)>0L)]$disabled <- NA

#Melt and cast
ghsp.wg.melt <- melt(ghsp.wg.cut, id.vars = c(1:5,12:14), na.rm=F)
ghsp.other.melt <- melt(ghsp.other.cut, id.vars = c(1:5,11:13), na.rm=F)
ghsp.wg <- dcast.data.table(ghsp.wg.melt, variable + age.group + SEX + employment + ZONE.x + `STATE CODE.x` + `LGA CODE.x` + SECTOR.x ~ value, fun=sum, value.var="SAMPLE.WEIGHT")
ghsp.other <- dcast.data.table(ghsp.other.melt, variable + age.group + SEX + employment + ZONE.x + `STATE CODE.x` + `LGA CODE.x` + SECTOR.x ~ value, fun=sum, value.var="SAMPLE.WEIGHT")

#Tidy columns
order <- c(names(ghsp.wg)[1:8],"CANNOT DO","YES, A LOT","YES, SOME","NO, NO DIFFICULTY","Disabled","Not disabled","NA")
ghsp.wg <- ghsp.wg[,..order]

#Calculate percentages across rows
ghsp.wg$count <- rowSums(ghsp.wg[,c(9:15)])
ghsp.wg[,9:15] <- ghsp.wg[,9:15]/rowSums(ghsp.wg[,16])

#Assign working-age column for those between 15-64
ghsp.wg$working.age <- "No"
ghsp.wg$working.age[ghsp.wg$age.group>=4&ghsp.wg$age.group<=13] <- "Yes"

#Split dichotomous disability from domains
ghsp.wg.domains <- ghsp.wg[,c(1:12,15:17)]
ghsp.wg.domains <- subset(ghsp.wg.domains, variable != "disabled")
ghsp.wg.overall <- subset(ghsp.wg, variable == "disabled")[,c(1:8,13:17)]

#Define 'impaired' as CANNOT DO & YES, A LOT
ghsp.wg.domains$impaired <- ghsp.wg.domains$`CANNOT DO`+ghsp.wg.domains$`YES, A LOT`
ghsp.wg.domains$`not impaired` <- ghsp.wg.domains$`YES, SOME`+ghsp.wg.domains$`NO, NO DIFFICULTY`

#Create dummy label for TOTAL
totallabel <- as.data.frame("TOTAL")
names(totallabel) <- "SEX"


###OUTPUTS###

#OVERALL PREVALENCE RATE
ghsp.wg.overall.all <- ghsp.wg.overall[, .(disabled=sum(count*Disabled)/sum(count),`not disabled`=sum(count*`Not disabled`)/sum(count),na=sum(count*`NA`)/sum(count)), by=.(SEX)]
ghsp.wg.overall.all <- rbind(ghsp.wg.overall.all,cbind(totallabel,ghsp.wg.overall[, .(disabled=sum(count*Disabled)/sum(count),`not disabled`=sum(count*`Not disabled`)/sum(count),na=sum(count*`NA`)/sum(count))]))
write.csv(ghsp.wg.overall.all,"output/GHSP WG all ages overall.csv", row.names = F)

#SHARE OF WORKING AGE POPULATION WHO ARE DISABLED, BY SEX
ghsp.wg.overall.working <- ghsp.wg.overall[working.age=="Yes", .(disabled=sum(count*Disabled)/sum(count),`not disabled`=sum(count*`Not disabled`)/sum(count),na=sum(count*`NA`)/sum(count)), by=.(SEX)]
ghsp.wg.overall.working <- rbind(ghsp.wg.overall.working,cbind(totallabel,ghsp.wg.overall[working.age=="Yes", .(disabled=sum(count*Disabled)/sum(count),`not disabled`=sum(count*`Not disabled`)/sum(count),na=sum(count*`NA`)/sum(count))]))
write.csv(ghsp.wg.overall.working,"output/GHSP WG WA overall.csv", row.names = F)

#SHARE OF WORKING AGE POPULATION WHO ARE DISABLED, BY SEX AND DOMAIN
ghsp.wg.domains.working <- ghsp.wg.domains[working.age=="Yes", .(impaired=sum(count*impaired)/sum(count),`not impaired`=sum(count*`not impaired`)/sum(count),na=sum(count*`NA`)/sum(count)), by=.(variable,SEX)]
ghsp.wg.domains.working <- rbind(ghsp.wg.domains.working,cbind(totallabel,ghsp.wg.domains[working.age=="Yes", .(impaired=sum(count*impaired)/sum(count),`not impaired`=sum(count*`not impaired`)/sum(count),na=sum(count*`NA`)/sum(count)), by=.(variable)]))
ghsp.wg.domains.working <- melt(ghsp.wg.domains.working, id.vars = c(1,2))
ghsp.wg.domains.working <- dcast(subset(ghsp.wg.domains.working, variable.1 == "impaired"), SEX ~ variable)
write.csv(ghsp.wg.domains.working,"output/GHSP WG WA domains.csv", row.names = F)

#WORKING AGE POPULATION WHO ARE DISABLED, BY GEOGRAPHY
ghsp.wg.state.working <- ghsp.wg.overall[working.age=="Yes", .(disabled=sum(count*Disabled)/sum(count),`not disabled`=sum(count*`Not disabled`)/sum(count),na=sum(count*`NA`)/sum(count)), by=.(`STATE CODE.x`)]
ghsp.wg.sector.working <- ghsp.wg.overall[working.age=="Yes", .(disabled=sum(count*Disabled)/sum(count),`not disabled`=sum(count*`Not disabled`)/sum(count),na=sum(count*`NA`)/sum(count)), by=.(`SECTOR.x`)]
write.csv(ghsp.wg.state.working,"output/GHSP WG WA states.csv", row.names = F)

#EMPLOYMENT RATE FOR WORKING AGE PWDS AND PWODS, BY SEX
ghsp.wg.overall.employ.1 <- ghsp.wg.overall[working.age=="Yes", .(disabled=sum(count*Disabled),not.disabled=sum(count*`Not disabled`)),by=.(employment,SEX)]
ghsp.wg.overall.employ.1 <- cbind(ghsp.wg.overall.employ.1[,1],ghsp.wg.overall.employ.1[, .(disabled=disabled/sum(disabled),not.disabled=not.disabled/sum(not.disabled)),by=SEX])
ghsp.wg.overall.employ.2 <- ghsp.wg.overall[working.age=="Yes", .(disabled=sum(count*Disabled),not.disabled=sum(count*`Not disabled`)),by=.(employment)]
ghsp.wg.overall.employ.2 <- cbind(ghsp.wg.overall.employ.2[,1],totallabel,ghsp.wg.overall.employ.2[, .(disabled=disabled/sum(disabled),not.disabled=not.disabled/sum(not.disabled))])
ghsp.wg.overall.employ <- rbind(ghsp.wg.overall.employ.1,ghsp.wg.overall.employ.2)
ghsp.wg.overall.employ <- ghsp.wg.overall.employ[complete.cases(ghsp.wg.overall.employ)]
ghsp.wg.overall.employ <- subset(ghsp.wg.overall.employ, employment != "unemployed")[,-1]
write.csv(ghsp.wg.overall.employ,"output/GHSP WG WA overall employment.csv", row.names = F)

#EMPLOYMENT RATE FOR WORKING AGE PWDS, BY SEX AND DOMAIN
ghsp.wg.domains.employ <- ghsp.wg.domains[working.age=="Yes", .(impaired=sum(count*impaired),not.impaired=sum(count*`not impaired`)),by=.(variable,SEX,employment)]
ghsp.wg.domains.employ <- rbind(ghsp.wg.domains.employ,cbind(totallabel,ghsp.wg.domains[working.age=="Yes", .(impaired=sum(count*impaired),not.impaired=sum(count*`not impaired`)),by=.(variable,employment)]))
ghsp.wg.domains.employ <- cbind(ghsp.wg.domains.employ$employment,ghsp.wg.domains.employ[, .(impaired=impaired/sum(impaired),not.impaired=not.impaired/sum(not.impaired)),by=.(variable,SEX)])
ghsp.wg.domains.employ <- melt(ghsp.wg.domains.employ, id.vars=c(1:3))
ghsp.wg.domains.employ <- dcast(subset(ghsp.wg.domains.employ, (variable.1 == "impaired" & V1 == "employed")), SEX ~ variable)
write.csv(ghsp.wg.domains.employ,"output/GHSP WG WA domains employment.csv", row.names = F)

rm(list=c("order","totallabel","ghsp.hha","ghsp.wg.cut","ghsp.wg.melt","ghsp.other.cut","ghsp.other.melt","ghsp.wg","ghsp.health","ghsp.hhr","ghsp.employ","ghsp.health.employ","ghsp.wg.domains","ghsp.wg.overall"))
