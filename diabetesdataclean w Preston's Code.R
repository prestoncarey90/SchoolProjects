# Packages that are used
#install.packages("ggplot2")
#install.packages("regclass")
#install.packages("tidyverse")
#install.packages("dplyr")
#install.packages("moderndive")
##install.packages("pROC")
#install.packages("pscl")
library(ggplot2)
library(regclass)
library(tidyverse)
library(dplyr)
library(moderndive)
library(pROC)
library(pscl)

(diabetes=read.csv("C:/Users/livym/OneDrive - The City University of New York/Desktop/School/STATOPR 9750/Final Project/diabetes.csv",fileEncoding="UTF-8-BOM"))
head(diabetes)
unique(diabetes$Pregnancies) #no null
unique(diabetes$Glucose) #clean 0s
unique(diabetes$BloodPressure) #clean 0s
unique(diabetes$SkinThickness) #no null
unique(diabetes$Insulin) #no null
unique(diabetes$BMI) #clean 0s
unique(diabetes$DiabetesPedigreeFunction) #no null
unique(diabetes$Age) #clean 0s
unique(diabetes$Outcome) #no null
dim(diabetes)

new.diabetes <- diabetes[-which(
  diabetes$Glucose == 0 |
    diabetes$BloodPressure == 0 |
    diabetes$BMI == 0 |
    diabetes$SkinThickness == 0 |
    diabetes$Insulin == 0 |
    diabetes$Pregnancies >= quantile(diabetes$Pregnancies,.75) + 1.5*IQR(diabetes$Pregnancies) | 
    diabetes$Pregnancies <= quantile(diabetes$Pregnancies,.25) - 1.5*IQR(diabetes$Pregnancies) |
    diabetes$Glucose >= quantile(diabetes$Glucose,.75) + 1.5*IQR(diabetes$Glucose) | 
    diabetes$Glucose <= quantile(diabetes$Glucose,.25) - 1.5*IQR(diabetes$Glucose) |
    diabetes$BloodPressure >= quantile(diabetes$BloodPressure,.75) + 1.5*IQR(diabetes$BloodPressure) | 
    diabetes$BloodPressure <= quantile(diabetes$BloodPressure,.25) - 1.5*IQR(diabetes$BloodPressure) | 
    diabetes$SkinThickness >= quantile(diabetes$SkinThickness,.75) + 1.5*IQR(diabetes$SkinThickness) | 
    diabetes$SkinThickness <= quantile(diabetes$SkinThickness,.25) - 1.5*IQR(diabetes$SkinThickness) |
    diabetes$Insulin >= quantile(diabetes$Insulin,.75) + 1.5*IQR(diabetes$Insulin) | 
    diabetes$Insulin <= quantile(diabetes$Insulin,.25) - 1.5*IQR(diabetes$Insulin) |
    diabetes$BMI >= quantile(diabetes$BMI,.75) + 1.5*IQR(diabetes$BMI) | 
    diabetes$BMI <= quantile(diabetes$BMI,.25) - 1.5*IQR(diabetes$BMI) |
    diabetes$DiabetesPedigreeFunction >= quantile(diabetes$DiabetesPedigreeFunction,.75) + 1.5*IQR(diabetes$DiabetesPedigreeFunction) | 
    diabetes$DiabetesPedigreeFunction <= quantile(diabetes$DiabetesPedigreeFunction,.25) - 1.5*IQR(diabetes$DiabetesPedigreeFunction) |
    diabetes$Age >= quantile(diabetes$Age,.75) + 1.5*IQR(diabetes$Age) | 
    diabetes$Age <= quantile(diabetes$Age,.25) - 1.5*IQR(diabetes$Age)),]

dim(new.diabetes)

#Logistic Regression
#1.Creating training & test samples (70:30).
set.seed(444)
sample <- sample(c(TRUE, FALSE), nrow(new.diabetes), replace=TRUE, prob=c(0.7,0.3))
train <- new.diabetes[sample,]
test <- new.diabetes[!sample,]

#2. Fitting the logistic model.
weights <- ifelse(train$Outcome == 1, 2.2, 1)
LogisticModel <- glm(Outcome~Glucose+Insulin+BMI+DiabetesPedigreeFunction+Age, family = "binomial", data=train, weights = weights)
summary(LogisticModel)

#3. Assessing Model Fit using McFadden's Psuedo-R^2 Score.
pscl::pR2(LogisticModel)["McFadden"]

#4. Using the Model to make predictions. 
predict.diabetes <- data.frame(Glucose=150,Insulin=90,BMI=38,DiabetesPedigreeFunction=0.622,Age=29)
pred_diabetes <- predict(LogisticModel,predict.diabetes,type = "response")
pred_diabetes

#5. Calculating probability of diabetes for each individual in test dataset & converting prediction to 0 & 1.
predict.test <- predict(LogisticModel,test,type="response")
predict.test
predict.test_class <- ifelse(predict.test>0.5, 1, 0)

#6. Evaluating Model Performance
roc_curve <- roc(test$Outcome, predict.test_class)
plot(roc_curve, main = "ROC Curve", col = "blue")
print(auc_value <- auc(roc_curve))

# Basic Scatterplots w/ Regression Lines
ggplot(new.diabetes, aes(y=Glucose, x=Pregnancies)) +
  geom_point() +
  labs(y="Glucose Levels", x="Number of Pregnancies") +
  geom_smooth(method = "lm", se = FALSE)
ggplot(new.diabetes, aes(y=Glucose, x=BloodPressure)) +
  geom_point() +
  labs(y="Glucose Levels", x="Blood Pressure") +
  geom_smooth(method = "lm", se = FALSE)
ggplot(new.diabetes, aes(y=Glucose, x=SkinThickness)) +
  geom_point() +
  labs(y="Glucose Levels", x="Skin Thickness") +
  geom_smooth(method = "lm", se = FALSE)
ggplot(new.diabetes, aes(y=Glucose, x=Insulin)) +
  geom_point() +
  labs(y="Glucose Levels", x="Insulin Level") +
  geom_smooth(method = "lm", se = FALSE)
ggplot(new.diabetes, aes(y=Glucose, x=BMI)) +
  geom_point() +
  labs(y="Glucose Levels", x="BMI") +
  geom_smooth(method = "lm", se = FALSE)
ggplot(new.diabetes, aes(y=Glucose, x=DiabetesPedigreeFunction)) +
  geom_point() +
  labs(y="Glucose Levels", x="Family History Score") +
  geom_smooth(method = "lm", se = FALSE)
ggplot(new.diabetes, aes(y=Glucose, x=Age)) +
  geom_point() +
  labs(y="Glucose Levels", x="Age") +
  geom_smooth(method = "lm", se = FALSE)

unique(new.diabetes$Insulin)
# Association Checks

# Glucose~Pregnancies
associate(Glucose~Pregnancies,data=new.diabetes,permutations=500,seed=9750)
associate(Glucose~BloodPressure,data=new.diabetes,permutations=500,seed=9750)
associate(Glucose~SkinThickness,data=new.diabetes,permutations=2000,seed=9750)
associate(Glucose~Insulin,data=new.diabetes,permutations=500,seed=9750)
associate(Glucose~BMI,data=new.diabetes,permutations=500,seed=9750)
associate(Glucose~DiabetesPedigreeFunction,data=new.diabetes,permutations=2000,seed=9750)
associate(Glucose~Age,data=new.diabetes,permutations=500,seed=9750)

# Pearson & Spearman Value Matrices
cor_matrix(new.diabetes, type="pearson")
cor_matrix(new.diabetes,type="spearman")

# Regression Tables
# Fit models
preg.diabetes <- lm(Glucose ~ Pregnancies, data = new.diabetes)
bp.diabetes <- lm(Glucose ~ BloodPressure, data = new.diabetes)
st.diabetes <- lm(Glucose ~ SkinThickness, data = new.diabetes)
ins.diabetes <- lm(Glucose ~ Insulin, data = new.diabetes)
BMI.diabetes <- lm(Glucose ~ BMI, data = new.diabetes)
dpf.diabetes <- lm(Glucose ~ DiabetesPedigreeFunction, data = new.diabetes)
age.diabetes <- lm(Glucose ~ Age, data = new.diabetes)

# Output regression tables
get_regression_table(preg.diabetes)
get_regression_table(bp.diabetes)
get_regression_table(st.diabetes)
get_regression_table(ins.diabetes)
get_regression_table(BMI.diabetes)
get_regression_table(dpf.diabetes)
get_regression_table(age.diabetes)

# Of the attributes that appear to have strong correlations with glucose,
# Insulin levels and Age appear to increase glucose levels the most, while the Diabetes Pedigree Function and BMI might affect it the least.

# Optional
# Split those with diabetes and those without.
has.diabetes <- new.diabetes[-which(
  diabetes$Outcome == 0),]
no.diabetes <- new.diabetes[-which(
  diabetes$Outcome == 1),]

# Overlapping Density Plots
ggplot() + 
  geom_density(data = has.diabetes, aes(x = Glucose, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = Glucose, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# There does appear to be a trend in glucose levels being less in those w/o diabetes, vs those with.

ggplot() + 
  geom_density(data = has.diabetes, aes(x = Pregnancies, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = Pregnancies, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# There does appear to be a trend in those with fewer pregnancies to not have diabetes.

ggplot() + 
  geom_density(data = has.diabetes, aes(x = BloodPressure, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = BloodPressure, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# There does appear to be a trend in blood pressure being greater in those w/o diabetes, vs those with.

ggplot() + 
  geom_density(data = has.diabetes, aes(x = SkinThickness, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = SkinThickness, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# There does appear to be a trend in skin thickness being thinner in those w/ diabetes, vs those w/o.

ggplot() + 
  geom_density(data = has.diabetes, aes(x = Insulin, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = Insulin, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# There appears to be no trend between those with diabetes and those without in levels of insulin.
# This could be the result of people living with diabetes managing their disease through insulin management.

ggplot() + 
  geom_density(data = has.diabetes, aes(x = BMI, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = BMI, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# There appears to be a small trend towards people with a higher BMI being without diabetes, and those with a lower BMI having it.

ggplot() + 
  geom_density(data = has.diabetes, aes(x = DiabetesPedigreeFunction, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = DiabetesPedigreeFunction, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# As previously mentioned, the relationship to a person's pedigree and having diabetes is weak,
# and except at very high levels, the similarity between those with diabetes and those w/o is almost identical.

ggplot() + 
  geom_density(data = has.diabetes, aes(x = Age, fill = "r"), alpha = 0.3) +
  geom_density(data = no.diabetes, aes(x = Age, fill = "b"), alpha = 0.3) +
  scale_colour_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes")) +
  scale_fill_manual(name ="Key", values = c("r" = "red", "b" = "blue"), labels=c("b" = "Does Not Have Diabetes", "r" = "Has Diabetes"))
# There is a noticible upward trend with more people who do not have diabetes being of higher ages.