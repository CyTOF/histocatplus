library(ggplot2);
df <- data.frame(column1 = seq(1:10), column2 = seq(1:10));
myPlot <- ggplot(data=df, aes(x=column1, y=column2, group=1))
+geom_line()+ylim(0,10);
print(myPlot);
ggsave(filename="ploti.png", path="~/Desktop", plot=myPlot);