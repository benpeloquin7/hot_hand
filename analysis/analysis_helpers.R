#####
##### inGlobalEnv()
##### -------------
##### boolean object presence in global env
#####
inGlobalEnv <- function(item) {
  item %in% ls(envir = .GlobalEnv)
}

#####
##### get_time_between_shots()
##### ------------------------
##### calculate time between shots within a quarter
#####
get_time_between_shots <- function(d) {
  quarter_data <- d %>% mutate(time_between_shots = NA) ## create new col
  
  for (row in 1:nrow(quarter_data)) {
    if (row == 1) {
      quarter_data[row, ]$time_between_shots <- NA
    }
    else {
      prev_row <- row - 1
      quarter_data[row, ]$time_between_shots <- quarter_data[prev_row, ]$TOTAL_TIME_REMAINING - quarter_data[row, ]$TOTAL_TIME_REMAINING
    }
  }
  quarter_data
}

#####
##### get_streaks()
##### -------------
##### find hit and miss streaks in data frame d
#####
get_streaks <- function(d) {
  
  ## Set-up df
  df <- d %>%
    mutate(prev_shot = lag(SHOT_MADE_FLAG),
           curr_hit_streak = NA,
           curr_miss_streak = NA)
 
   ## Store shot number
  df$shot_num <- seq(1, nrow(d))
  
  ## Store time between shots
  df <- plyr::ddply(df, .variables = c("PERIOD"), .fun = get_time_between_shots)
  
  ## Store streak data
  for (row in 1:nrow(df)) {
    ## First hot
    if (row == 1) {
      df[row, ]$curr_hit_streak <- 0
      df[row, ]$curr_miss_streak <- 0
    }
    ## Add to hit streak
    else if (df[row, ]$prev_shot == 1) {
      df[row, ]$curr_hit_streak <- df[row - 1, ]$curr_hit_streak + 1
      df[row, ]$curr_miss_streak <- 0
    }
    ## Add to miss streak
    else {
      df[row, ]$curr_miss_streak <- df[row - 1, ]$curr_miss_streak + 1
      df[row, ]$curr_hit_streak <- 0
    }
  }
  
  ## Return new df
  df
}

########
######## populate_prev_shots()
######## ---------------------
######## Populate new column with hit / miss streak data up to that point
########
populate_prev_shots <- function(d) {
  d_prev <-  plyr::ddply(d, .variables = c("PLAYER_ID", "GAME_ID"), .fun = get_streaks)
  
  d_prev
}

########
######## calc_runs()
######## ---------------------
######## Calcuate statistic and p-value of Wald-Wolfowitz run test
######## Code adopted from runs.pvalue from randomizeBE
########
calc_runs <- function(y, pmethod = c("exact", "normal", "cc")) {
  pmethod <- match.arg(pmethod)
  y <- na.omit(y)
  yuniq <- unique(y)
  if (length(yuniq) == 2) {
    s <- as.numeric(y)
    s[yuniq[1] == y] <- -1
    s[yuniq[2] == y] <- +1
  }
  else {
    med <- median(y, na.rm = TRUE)
    s <- sign(y - med)
    s[s == 0] <- +1
  }
  n <- length(s)
  R <- 1 + sum(as.numeric(s[-1] != s[-n]))
  n1 <- sum(s == +1)
  n2 <- sum(s == -1)
  n <- n1 + n2
  E <- 1 + 2 * n1 * n2/n
  s2 <- (2 * n1 * n2 * (2 * n1 * n2 - n))/(n^2 * (n - 1))
  ccf <- 0
  if (pmethod == "cc" | pmethod == "exact") {
    ccf <- ifelse((R - E) < 0, +0.5, -0.5)
  }
  statistic <- (R - E + ccf)/sqrt(s2)
  if ((n > 30 & n1 > 12 & n2 > 12) | pmethod != "exact") {
    pvalue <- 2 * pnorm(-abs(statistic))
  }
  else {
    pvalue <- pruns.exact(R, n1, n2, tail = "2-sided")
  }
  c(statistic, pvalue)
}

