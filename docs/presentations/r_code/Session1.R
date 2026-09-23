# setwd("/PathToMyDownload/RU_Course_template/docs")
# # e.g. setwd("~/Downloads/Intro_To_R_1Day/r_course")

Table <- read.table("data/readThisTable.csv",sep=",",header=T)

# #Intense computation
# myresult<-10^6 +1

load("data/myresult.RData")

# 
# boxplot(Table[,2:7])
# 
# 

boxplot(Table[,2:7])

