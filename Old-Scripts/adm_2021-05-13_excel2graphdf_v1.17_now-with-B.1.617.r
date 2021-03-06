library(readxl)
library(plyr)
library(dplyr)
library(lubridate)
library(scales)

# ______________________________________________________________________________
# Define the graphing function
graph_sars <- function(df_original, lineage_important, title, rationale_list, graph_type, date_start, date_stop, date_label, time_bin, breaks_num, bar_width, scale){

# Make a new dataframe with only the necessary columns
df1 <- df_original[,c("sample_date", "lineage", "rationale")]

# Remove missing dates from df1
df2 <- na.omit(df1)

# Make the date column a date object
df2$sample_date <- as.Date(df2$sample_date, "%Y-%m-%d")

# Make a data frame for the rationales selected
df3 <- data.frame(Date=as.Date(character()),
                       File=character(), 
                       User=character(), 
                       stringsAsFactors=FALSE)
for(rl in 1:length(rationale_list)){
  df3 <- rbind(df3, df2[df2$rationale == rationale_list[rl],])
}
df4 <- df3
if(rationale_list[1] == 'All'){
  df4 <- df2
}

# Summarize the data
df4$sample_date_week <- floor_date(df4$sample_date, time_bin) # Adds a column with date for the week only
df5 <- ddply(df4, c("sample_date_week", "lineage"), summarise, n = length(lineage)) # Makes a new dataframe with the counts of each lineage for each of the week categories
df6 <- na.omit(df5) # Remove any data that does not have an associated date

# Make a list of the unique dates and lineages
lineage_unique <- unique(df6[c("lineage")])
date_week_unique <- unique(df6[c('sample_date_week')])

# Add important lineages to unique lineages. This makes sure the color assigned to lineages is consistent.
for(li in 1:length(lineage_important)){
  lineage_unique <- lineage_unique %>% add_row(lineage = lineage_important[li])
}
lineage_unique <- unique(lineage_unique[c("lineage")])

# Make the columns of the graph with the repeating lineages for each date
lineage_repeat <- lineage_unique
for(d in 2:lengths(date_week_unique)){
  lineage_repeat <- Map(c, lineage_repeat, lineage_unique)
}

# Make the column of the graph with the repeating date, where there are enough dates for each lineage.
date_repeat <- list(sample_date = date_week_unique[1,1])
for(d in 1:lengths(date_week_unique)){
  for(l in 1:lengths(lineage_unique)){
    date_repeat <-Map(c, date_repeat, date_week_unique[d,1])
  }
} 
lengths(date_repeat)

# Remove the initial repeated date from the creation of this new list
date_repeat <- date_repeat$sample_date[-2]
date_repeat <- list(sample_date = date_repeat)
lengths(date_repeat)

# Combine the repeated dates and lineages into a single data frame
df7 <- c(date_repeat, lineage_repeat)
df7 <- data.frame(df7)

# Make a list of zero counts to be temporary placeholders.  
count_zero <- rep(c(0),each=length(df7$sample_date))
count_zero <- list(counts = count_zero)
df8 <- c(date_repeat, lineage_repeat, count_zero)
df8 <- data.frame(df8)

# Loop through the data to determine which dates have counts for each lineage and replace zero placeholders with appropriate counts
short_length <- length(df6$sample_date_week)
long_length <- length(df8$sample_date)
for(s in 1:short_length){
  temp_short_date <- df6[s,1]
  temp_short_lineage <- df6[s,2]
  for(l in 1:long_length){
    temp_long_date <- df8[l,1]
    temp_long_lineage <- df8[l,2]
    if(temp_short_date == temp_long_date && temp_short_lineage == temp_long_lineage){
      df8[l,3] <- df6[s,3] 
    }
  }
}

# Load libraries required for graphing the data
library(ggplot2)
library(viridis)
library(hrbrthemes)

# Apply the date cut off to include reads only as old as the date_start specified
df9 <- df8 %>%
  select(sample_date, lineage, counts) %>%
  filter(sample_date >= as.Date(date_start)) %>%
  filter(sample_date <= as.Date(date_stop))

# Assign data frame
data <- df9

# Convert variant counts to percentages
data2 <- data  %>%
  group_by(sample_date, lineage) %>%
  summarise(n = sum(counts)) %>%
  mutate(percentage =100 * n / sum(n),
         date=as.Date(sample_date, "%m/%d/%Y")) %>%
  ungroup() %>% as.data.frame()

# Determine which lineages to drop
lineage_unique2 <- c("")
for(lu in 1:lengths(lineage_unique)){
  lineage_unique2 <- c(lineage_unique2, lineage_unique[lu,1])
}
lineage_unique2 <- c(lineage_unique2[2:length(lineage_unique2)])
lineage_drop <- setdiff(lineage_unique2, lineage_important)
#lineage_drop <- c("NA")

# Lump variants into 'Other' category
df9 %>%
  as_tibble() %>%
  mutate(date = as.Date(sample_date, "%Y-%m-%d")) %>%
  # Lumped "Other" Variants chosen at random here
  mutate(Lineage = factor(lineage),
         Lineage = forcats::fct_other(f = Lineage, drop = lineage_drop, other_level = "Other")) %>%
  group_by(date, Lineage) %>%
  summarise(Lineage_count = sum(counts, na.rm = TRUE)) %>%
  ungroup() %>%
  group_by(date) %>%
  mutate(Lineage_perc = 100 * Lineage_count / sum(Lineage_count)) %>%
  ungroup() %>%
  identity() -> data3

# Add specimen totals
data3 %>%
  group_by(date) %>%
  summarise(total_seqs = sum(Lineage_count, na.rm = TRUE)) %>%
  ggplot(data = ., aes(x = date, y = total_seqs)) +
  geom_point() +
  geom_line() +
  theme_ipsum() +
  labs(x = "Date", y = "Genomes Sequenced")

# Add colloquial names
data4 <- data3
data4 <- data.frame(lapply(data4, function(x) {gsub("B.1.526.1", "temp_lineage_01", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("B.1.526", "B.1.526 (NY)", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("B.1.1.7", "B.1.1.7 (UK)", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("P.1", "P.1 (Brazil)", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("B.1.351", "B.1.351 (South Africa)", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("B.1.427", "B.1.427 (California)", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("B.1.429", "B.1.429 (California)", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("B.1.617", "B.1.617 (India)", x)}))
data4 <- data.frame(lapply(data4, function(x) {gsub("temp_lineage_01", "B.1.526.1 (NY)", x)}))
data4$date <- as.Date(data4$date)
data4$Lineage <- as.factor(data4$Lineage)
data4$Lineage_count <- as.numeric(data4$Lineage_count)
data4$Lineage_perc <- as.numeric(data4$Lineage_perc)
data4$Lineage <- factor(data4$Lineage, levels = c("B.1", "B.1.1.7 (UK)", "B.1.2", "B.1.243", "B.1.311", "B.1.351 (South Africa)", "B.1.427 (California)", "B.1.429 (California)", "B.1.525", "B.1.526 (NY)", "B.1.526.1 (NY)", "B.1.617 (India)", "P.1 (Brazil)", "P.2", "Other"))

# Plot lineages using line graph
if(graph_type == 'line'){
  p1 <- ggplot(data4,aes(x=date, y=Lineage_perc, fill=Lineage)) +
    geom_area(alpha=0.6 , size=.5, color="white") +
    labs(fill = "", x = "Date", y = "Percentage") +
    theme_ipsum() +
    ggtitle("Philadelphia Random Sampling SARS-CoV-2 Variants") +
    scale_x_date(date_labels = date_label, breaks = breaks_pretty(4)) +
    guides(fill=guide_legend(title="Lineage")) +
    scale_fill_manual(values = c("yellow2", "palegreen", "lightseagreen", "skyblue", "steelblue1", "royalblue", "navy", "purple", "hotpink", "indianred", "red", "orangered", "orange","lightgoldenrod1", "honeydew4"))
}

# Plot lineages using bar graph
if(graph_type == 'bar'){
  p1 <- ggplot(data4, aes(fill=Lineage, y=Lineage_perc, x=date)) +
    geom_bar(position="stack", stat="identity") +
    theme_ipsum() +
    ggtitle(title) +
    labs(x = "Date", y = "Percentage") +
    scale_x_date(date_labels = date_label, breaks = breaks_pretty(breaks_num)) + 
    scale_fill_manual(values = c("yellow2", "palegreen", "lightseagreen", "skyblue", "steelblue1", "royalblue", "navy", "purple", "hotpink", "indianred", "red", "orangered", "orange","lightgoldenrod1", "honeydew4"))
}

# Plot sequencing counts using bar graph
p2 <- data4 %>%
  group_by(date) %>%
  summarise(total_seqs = sum(Lineage_count, na.rm = TRUE)) %>%
  ggplot(data = ., aes(x = date, y = total_seqs)) +
  geom_bar(position="stack", stat="identity", width = bar_width) +
  theme_ipsum() +
  labs(x = "Date", y = "Genomes") +
  scale_x_date(date_labels = date_label, breaks = breaks_pretty(breaks_num)) +
  if(scale == 'log'){
    scale_y_continuous(trans = 'log2')
  }

# Combine lineages and sequence counts graphs
library(patchwork)
p1 + p2 + plot_layout(ncol = 1, heights = c(1,0.4), guides = 'collect') 
}

#_______________________________________________________________________________
# User modifiable variables

# General parameters
file <- '2021-05-11_genomeMetaData.xlsx'
lineage_important <- c("B.1.526", "B.1.526.1", "B.1.525", "P.2", "B.1.1.7", "P.1", "B.1.351", "B.1.427", "B.1.429", "B.1.311",  "B.1", "B.1.2", "B.1.243", "B.1.617")
df_original <- read_excel(file)

# Graph 1: All Samples
title <- 'Philadelphia SARS-CoV-2 Variants'
rationale_list <- list('All')
graph_type <- 'bar'
date_start <- '2020-01-01'
date_stop <- '2021-03-27'
date_label <- "%b %Y"
time_bin <- 'week'
breaks_num <- 6
bar_width <- 5
scale <- 'log'
g1 <- graph_sars(df_original, lineage_important, title, rationale_list, graph_type, date_start, date_stop, date_label, time_bin, breaks_num, bar_width, scale)
g1

# # Graph 2: All Random Samples
# title <- 'Philadelphia Random Sample SARS-CoV-2 Variants'
# rationale_list <- list('Asymptomatic', 'Hospitalized', 'Random')
# graph_type <- 'line'
# date_start <- '2021-02-28'
# date_stop <- '2021-03-27'
# date_label <- "%b %d"
# time_bin <- 'week'
# breaks_num <- 5
# bar_width <- 5
# scale <- 'log'
# g2 <- graph_sars(df_original, lineage_important, title, rationale_list, graph_type, date_start, date_stop, date_label, time_bin, breaks_num, bar_width, scale)
# g2
# 
# # Graph 3: Asymptomatic Samples
# title <- 'Philadelphia Asymptomatic SARS-CoV-2 Variants'
# rationale_list <- list('Asymptomatic')
# graph_type <- 'bar'
# date_start <- '2020-01-01'
# date_stop <- '2021-03-27'
# date_label <- "%b %Y"
# time_bin <- 'month'
# breaks_num <- 5
# bar_width <- 10
# scale <- 'linear'
# g3 <- graph_sars(df_original, lineage_important, title, rationale_list, graph_type, date_start, date_stop, date_label, time_bin, breaks_num, bar_width, scale)
# g3
# 
# # Graph 4: Hospitalized Samples
# title <- 'Philadelphia Hospitalized SARS-CoV-2 Variants'
# rationale_list <- list('Hospitalized')
# graph_type <- 'bar'
# date_start <- '2020-01-01'
# date_stop <- '2021-03-27'
# date_label <- "%b %Y"
# time_bin <- 'month'
# breaks_num <- 5
# bar_width <- 10
# scale <- 'linear'
# g4 <- graph_sars(df_original, lineage_important, title, rationale_list, graph_type, date_start, date_stop, date_label, time_bin, breaks_num, bar_width, scale)
# g4
# 
# # Graph 5: Spike Drop Out
# title <- 'Philadelphia Spike Drop Out SARS-CoV-2 Variants'
# rationale_list <- list('Random; S drop', 'S Drop', 'S drop out', 'S drop out; Vaccine Breakthrough', 'Random; Vaccine Breakthrough, S drop')
# graph_type <- 'bar'
# date_start <- '2020-01-01'
# date_stop <- '2021-03-27'
# date_label <- "%b %Y"
# time_bin <- 'week'
# breaks_num <- 5
# bar_width <- 3
# scale <- 'linear'
# g5 <- graph_sars(df_original, lineage_important, title, rationale_list, graph_type, date_start, date_stop, date_label, time_bin, breaks_num, bar_width, scale)
# g5
# 
# # Graph 6: Vaccine Breakthrough
# title <- 'Philadelphia Vaccine Breakthrough SARS-CoV-2 Variants'
# rationale_list <- list('Vaccine breakthrough', 'S drop out; Vaccine Breakthrough', 'Random; Vaccine Breakthrough', 'S drop out; Vaccine Breakthrough', 'Random; Vaccine Breakthrough, S drop')
# graph_type <- 'bar'
# date_start <- '2020-01-01'
# date_stop <- '2021-03-27'
# date_label <- "%b %Y"
# time_bin <- 'month'
# breaks_num <- 3
# bar_width <- 5
# scale <- 'linear'
# g6 <- graph_sars(df_original, lineage_important, title, rationale_list, graph_type, date_start, date_stop, date_label, time_bin, breaks_num, bar_width, scale)
# g6
