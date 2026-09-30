rm(list = ls())
library(dplyr)
library(lubridate)
library(zoo)
library(ggplot2)
library(forecast)
library(zoo)
library(astsa)
library(tseries)
library(psych)

df <- read.table("data/household_power_consumption.txt",
                 header = TRUE, sep = ";",
                 na.strings = "?", stringsAsFactors = FALSE)

df$DateTime <- as.POSIXct(paste(df$Date, df$Time),
                          format = "%d/%m/%Y %H:%M:%S")

dfnew <- df %>% select(DateTime, Global_active_power, Global_reactive_power,
                       Voltage, Global_intensity, Sub_metering_1,
                       Sub_metering_2, Sub_metering_3)

sum(is.na(dfnew$Global_active_power))
dfnew$Global_active_power <- na.approx(dfnew$Global_active_power, na.rm = TRUE)
sum(is.na(dfnew$Global_active_power))

dfnew$Month <- floor_date(dfnew$DateTime, "month")


monthly_avg <- dfnew %>%
  group_by(Month) %>%
  summarise(monthly_avg_power = mean(Global_active_power, na.rm = TRUE)) %>%
  na.omit()


dfnew <- dfnew %>%
  left_join(monthly_avg, by = "Month")

x <- ts(monthly_avg$monthly_avg_power,start = c(2006, 12),  frequency = 12)

class(x)
typeof(x) 

describe(x)
#mean and median are almost same and skewness is very less so assuming normal distribuiton
shapiro.test(x)
#p value greater than 0.5 significance level
#normal distribution is confirmed

autoplot(x)
summary(x)
head(x)
x


#additive
xa = decompose(x,type = "additive")
#multiplicative
xm = decompose(x,type = "multiplicative")

autoplot(xa)

autoplot(xm)

#looks like additive because varinace is almost constant in ups and dips

m<-mstl(x,lambda = "auto", s.window = "periodic")
autoplot(m)
autoplot(stlf(x))


ets(x)

# stlf and ets tells additve trend so our prediction is correct, fitting classical models

# CLASSICAL METHODS
par(mfrow=c(1,2))

fcast1 <- hw(x, seasonal="multiplicative",
             h=1*12,damped = F)
plot(fcast1)
accuracy(fcast1)

fcast2 <- hw(x, seasonal="additive",h=1*12, damped = F)
plot(fcast2)
accuracy(fcast2)

#from classical models hw additive gives a good predcition and MAE has no significant difference

fcast1;fcast2
summary(fcast1);summary(fcast2)

adf.test(x) #h0 = non stationary, ha = stationary
kpss.test(x) #h0 = stationary, ha = non stationary


decompose(x)
autoplot(decompose(x))
acf2(x)
# the dataset is stationary but have seasonality components
# we choose additive aswell so no logs is needed 
#only seasonality difference is needed

dsx <- diff(x, lag=12, differences = 1) 
autoplot(decompose(dsx))
acf2(dsx)

# P D Q
# 0 1 0
#0 1 1
#1 1 0 
# 1 1 1

#li jounx test
sarima(x,0,0,0,0,1,0,12) 
summary(sarima(x,0,0,0,0,1,0,12))
sarima(x,0,0,0,0,1,1,12) #selected
summary(sarima(x,0,0,0,0,1,1,12))
sarima(x,0,0,0,1,1,0,12)
summary(sarima(x,0,0,0,1,1,0,12))
sarima(x,0,0,0,1,1,1,12)
summary(sarima(x,0,0,0,1,1,1,12))

#aic value is -0.80 which is lowest so selecting sarima(x,0,0,0,0,1,1,12)

auto.arima(x)
summary(auto.arima(x))

#auto arima our model says the sarima(x,0,0,0,0,1,0,12) because the aic difference is less and paremters are less
#selecting auto arima model lesser parameter simpler model

dfis<-arima(x , order = c(0,0, 0),seasonal = list(order = c(0,1,0),period=12))

#check resiuals 
checkresiduals(dfis)

#0ur model residuals follow normal distribution


#autoplot(forecast(dfi))

predict_1 = predict(dfis, n.ahead = 1*12)
predict_1
predict_2 = predict_1$pred

ts.plot(x,predict_2,lty=c(1,3) )

#forecast
fc= forecast(dfis, h = 1*12)

dev.off()
plot(fc)

# forecasting last periods of time series and compare them with the actual observed values
# Split: last 12 months for testing
train <- window(x, end = c(2009, 11))
test <- window(x, start = c(2009, 12))

# Fitting models and prediction is made
hw_fc <- forecast(hw(train, seasonal = "additive", h = 12))$mean
arima_fc <- forecast(auto.arima(train, seasonal = TRUE), h = 12)$mean

#Summary table
results <- data.frame(
  Month = c("Dec 2009", "Jan 2010", "Feb 2010", "Mar 2010", "Apr 2010", 
            "May 2010", "Jun 2010", "Jul 2010", "Aug 2010", "Sep 2010", 
            "Oct 2010", "Nov 2010"),
  Actual = round(as.numeric(test), 2),
  HoltWinters = round(as.numeric(hw_fc), 2),
  AutoARIMA = round(as.numeric(arima_fc), 2)
)

print(results)
# Calculate RMSE from the results table
hw_rmse <- sqrt(mean((results$Actual - results$HoltWinters)^2))
arima_rmse <- sqrt(mean((results$Actual - results$AutoARIMA)^2))

# Show kWich is better
cat("RMSE Comparison:")
cat("Holt-Winters:", round(hw_rmse, 3))
cat("Auto ARIMA:  ", round(arima_rmse, 3))

#from this found Best model: Auto ARIMA beacuse of lower rmse

