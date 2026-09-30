suppressMessages({library(dplyr);library(lubridate);library(zoo);library(forecast);library(ggplot2)})
df <- read.table("data/household_power_consumption.txt", header=TRUE, sep=";", na.strings="?", stringsAsFactors=FALSE)
df$DateTime <- as.POSIXct(paste(df$Date, df$Time), format="%d/%m/%Y %H:%M:%S")
df$Global_active_power <- na.approx(df$Global_active_power, na.rm=TRUE)
df$Month <- floor_date(df$DateTime, "month")
m <- df %>% group_by(Month) %>% summarise(p=mean(Global_active_power, na.rm=TRUE)) %>% na.omit()
x <- ts(m$p, start=c(2006,12), frequency=12)
train <- window(x, end=c(2009,11)); test <- window(x, start=c(2009,12))
set.seed(1)
hw_fc <- forecast(hw(train, seasonal="additive", h=12))$mean
ar <- auto.arima(train, seasonal=TRUE); arima_fc <- forecast(ar, h=12)$mean
rm_hw <- sqrt(mean((as.numeric(test)-as.numeric(hw_fc))^2)); rm_ar <- sqrt(mean((as.numeric(test)-as.numeric(arima_fc))^2))
cat(sprintf("n_test=%d HW_RMSE=%.3f ARIMA_RMSE=%.3f model=%s\n", length(test), rm_hw, rm_ar, paste(capture.output(print(ar))[2], collapse="")))
dd <- function(s,l) data.frame(date=as.Date(as.yearmon(time(s))), kw=as.numeric(s), series=l)
d <- rbind(dd(x,"Actual"), dd(hw_fc,sprintf("Holt-Winters (RMSE %.3f)",rm_hw)), dd(arima_fc,sprintf("Auto ARIMA (RMSE %.3f)",rm_ar)))
g <- ggplot(d, aes(date, kw, colour=series, linetype=series)) + geom_line(linewidth=0.9) +
  annotate("rect", xmin=as.Date("2009-12-01"), xmax=max(d$date), ymin=-Inf, ymax=Inf, alpha=0.08) +
  scale_colour_manual(values=c("grey20","#2a78d6","#e8762c")) + scale_linetype_manual(values=c("solid","dashed","dashed")) +
  labs(title="Monthly household power: 12-month hold-out forecast", x=NULL, y="Avg global active power (kW)", colour=NULL, linetype=NULL) +
  theme_minimal(base_size=13) + theme(legend.position="bottom")
ggsave("images/holdout_forecast.png", g, width=10, height=5, dpi=120, bg="white")
