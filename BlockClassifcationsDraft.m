clear; clc; close all; instrreset;
%% Connect to Device
r = MKR_MotorCarrier;
%% Define boxes, count, and setup for saving data
blockClass = [0 1 2]; % Zero bad, One good, 2 Excellent
trialCount = 25;
%trialCount = 6;
saveDirectory = [pwd, '\data'];

%% Collect Data
% Setup places to store data and start data stream
blockCount = length(blockClass);
data = cell(blockCount, trialCount);
r.startStream('analog');

% temp data holders
red = 0;
green = 0;
blue = 0;
ClawSize = 0;
% readings = zeros(3, 1);
readings = zeros(5, 1);
a = 1;
b = 1;
BadMin = zeros(5,1);
BadMax = zeros(5,1);
GoodMin = zeros(5,1);
GoodMax = zeros(5,1);
ExcelMin = zeros(5,1);
ExcelMax = zeros(5,1);
first = true;


for class = 1:3
% Begin gathering data
if(class == 1)
    countdown("Beginning Recording Bad blocks in", 3);
elseif(class == 2)
    countdown("Beginning Recording Good blocks in", 3);
else
    countdown("Beginning Recording Excellent blocks in", 3);
end
for x = 1:trialCount
    if(class == 1)
        fprintf("Please Place Bad Block, Trial No. %d\n", x);
    elseif(class == 2)
        fprintf("Please Place Good Block, Trial No. %d\n", x);
    else
        fprintf("Please Place Excellent Block, Trial No. %d\n", x);
    end
    while(input("Start recording\n","s") ~= "start")
    end
    fprintf("reading data");
    [red, green, blue] = r.rgbRead();
    AnalogData = r.getAverageData('analog', 10);
    ClawSize = CloseClaw(r);
    pause(0.2)

        readings(1, 1) = AnalogData(1);
        readings(2, 1) = red;
        readings(3, 1) = green;
        readings(4, 1) = blue;
        readings(5, 1) = ClawSize;
%     readings(1, 1) = AnalogData(1);
%     readings(2, 1) = red + green + blue;
%     readings(3, 1) = ClawSize;

    if(first == true)
        BadMin = readings;
        BadMax = readings;
        first = false;
    else
        BadMin = CalcNewMins(readings, BadMin);
        BadMax = CalcNewMaxs(readings, BadMax);
    end

    data{a, b} = readings;
    b = b + 1;
    pause(0.5);
    clc;
end

a = a + 1;
b = 1;
first = true;
end

r.stopStream('analog');  % stop streaming accelerometer
r.close; % disconnect from the MKR
pause(1); % wait a second
clc; % clear command line

if ~exist(saveDirectory, 'dir') %check if a data folder already exists
    mkdir(saveDirectory) %make folder if not
end
filename = ['data_2_', getenv('COMPUTERNAME'), '_', datestr(now,'yyyy-mm-dd-HH-MM-ss')];
save(filename,'data') %save data

% For Loading Data
% matObj = matfile('nameoffile.mat');
% then do
% data = matObj.data;
% this will read the cell from the struct into data

%%  Normalize Data
% Normalize Data formula (X - Xmin) / (Xmax - Xmin)
dataCell = zeros(3,1);

% Normalize Bad Row of Cell
% Setup Denominators for Bad's RGB and HallEffect
DenomHe = BadMax(1, 1) - BadMin(1, 1);
DenomRGB = BadMax(2, 1) - BadMin(2, 1);
for b = 1:trialCount
    dataCell = data{1, b};
    dataCell(1,1) = (dataCell(1,1) - BadMin(1,1)) / DenomHe;
    dataCell(2,1) = (dataCell(2,1) - BadMin(2,1)) / DenomRGB;
    data{1,b} = dataCell;
end

% Normalize Good Row of Cell
DenomHe = GoodMax(1, 1) - GoodMin(1, 1);
DenomRGB = GoodMax(2, 1) - GoodMin(2, 1);
for b = 1:trialCount
    dataCell = data{2, b};
    dataCell(1,1) = (dataCell(1,1) - GoodMin(1,1)) / DenomHe;
    dataCell(2,1) = (dataCell(2,1) - GoodMin(2,1)) / DenomRGB;
    data{2,b} = dataCell;
end

%Normalize Excellent Row of Cell
DenomHe = ExcelMax(1, 1) - ExcelMin(1, 1);
DenomRGB = ExcelMax(2, 1) - ExcelMin(2, 1);
for b = 1:trialCount
    dataCell = data{3, b};
    dataCell(1,1) = (dataCell(1,1) - ExcelMin(1,1)) / DenomHe;
    dataCell(2,1) = (dataCell(2,1) - ExcelMin(2,1)) / DenomRGB;
    data{3,b} = dataCell;
end
%%  Calculate Features
Features = zeros(blockCount, trialCount, 5);
for y = 1:blockCount
    for z = 1:trialCount
        blockType = data{y, z};

        Features(y, z, :) = mean(blockType');
    end
end

%% Plot Features
figure(); hold on; grid on;
for a = 1:blockCount
    scatter3(Features(a,:,1), Features(a, :, 2), Features(a,:,3), Features(a,:,4), Features(a,:,5), 'filled');
end

%% Perform Linear Discriminate analysis
TrainingFeatures = reshape(Features, [trialCount*blockCount, 5]);
TrainingLabels = repmat(blockClass, [2, trialCount]);
LDA = fitcdiscr(TrainingFeatures, TrainingLabels);

%% Plot again
figure(); hold on; grid on;
for a = 1:blockCount
    scatter3(Features(a,:,1), Features(a, :, 2), Features(a,:,3), Features(a,:,4), Features(a,:,5), 'filled');
end
limits = [xlim, ylim, zlim];
K = LDA.Coeffs(1, 2).Const;
L = LDA.coeffs(1, 2).Linear;
f = @(x1, x2, x3) K + L(1)*x1 + L(2)*x2 +  L(3)*x3;
h2 = fimplicit(f, limits);
%% get raw data
training_examples_raw = zeros(5,75);

i = 1;
for row = 3:5
    temp = cell2mat(data(row,:));
    for col = temp
        training_examples_raw(:,i) = col;
        i = i+1;
    end
end

training_examples = training_examples_raw;
%% Normalize data
MAX_SIZE = max(training_examples(5,:));
MIN_SIZE = min(training_examples(5,:));

MAX_HALL = max(training_examples(1,:));
MIN_HALL = min(training_examples(1,:));

CONSTS = [MAX_SIZE,MIN_SIZE,MAX_HALL,MIN_HALL];

colors = (training_examples_raw(2:4,:));
hall_effect = training_examples(1,:);

size_b = training_examples(5,:);
training_examples(5,:) = (size_b - min(size_b))./(max(size_b) - min(size_b)); %normalize size

training_examples(2:4,:) = training_examples(2:4,:)./255; %normalize colors
training_examples(1,:) = (training_examples(1,:) - min(hall_effect))./(max(hall_effect) - min(hall_effect));

colors = (training_examples(2:4,:));
hall_effect = training_examples(1,:);
size_b = training_examples(5,:);
% coef = pca(colors);

Y = zeros(1,75);
Y(1:25) = 0; %% bad == 0
Y(26:50) = 1; %% good == 1
Y(51:75) = 2; %% excellent == 2

%% Visualization red
% scatter3(hall_effect(1:25), size(1:25), colors(1,1:25),50, "red", 'o') % bad
% hold on
% scatter3(hall_effect(26:50), size(26:50), colors(1,26:50),50, "blue", '+') % good
% hold on
% scatter3(hall_effect(51:75), size(51:75), colors(1,51:75),50, "green", '*') % excellent
% hold on
% % Visualization green
% scatter3(hall_effect(1:25), size(1:25), colors(2,1:25),50, "red", 'o') % bad
% hold on
% scatter3(hall_effect(26:50), size(26:50), colors(2,26:50),50, "blue", '+') % good
% hold on
% scatter3(hall_effect(51:75), size(51:75), colors(2,51:75),50, "green", '*') % excellent
% hold on
% % Visualization blue
% scatter3(hall_effect(1:25), size(1:25), colors(3,1:25),50, "red", 'o') % bad
% hold on
% scatter3(hall_effect(26:50), size(26:50), colors(3,26:50),50, "blue", '+') % good
% hold on
% scatter3(hall_effect(51:75), size(51:75), colors(3,51:75),50, "green", '*') % excellent

%% pca 
% scatter3(hall_effect(1:25), size(1:25), coef(1:25,1)',50, "red", 'o') % bad
% hold on
% scatter3(hall_effect(26:50), size(26:50), coef(26:50,1)',50, "blue", '+') % good
% hold on
% scatter3(hall_effect(51:75), size(51:75), coef(51:75,1)',50, "green", '*') % excellent

%% separate into training and testing sets
train_set = zeros(5,65);
test_set = zeros(5,10);
Y_train = zeros(1,65);
Y_test = zeros(1,10);

i = 1; j = 1;
for cat = 1:3
    offset = 15*(cat-1);
    for col = 1:15
        train_set(:,i) = training_examples(:,col + offset);
        Y_train(:,i) = Y(:,col + offset);

        i = i+1;
    end
    for col = 16:25
        test_set(:,j) = training_examples(:, col + offset);
        Y_test(:,j) = Y(:,col + offset);

        j = j+1;
    end
end

classes = unique(Y);

%%
X(:,1:150) = training_examples_1;
X(:,151:300) = training_examples;
Result(:,1:150) = Y;
Result(:,151:300) = Y;
%% SVM
t = templateSVM('Standardize',true,'KernelFunction','polynomial');

model = fitcecoc(training_examples', Y,'Learners',t, 'FitPosterior',true,...
    'ClassNames', classes);
%% Test 
correct = 0;
for i = 1:10
    result = model.predict(test_set(:,i)') == Y_test(i);
    if(result == true)
        correct = correct +1;
    end
end
acc = round(correct./10*100);
fprintf("Accuracy %d\n", acc);
%% Claw Code Function
function size = CloseClaw(obj)
obj.servo(4,0);

previousAnalogVal = 0;
currentAnalogVal = 0;
for i = 10:10:180
    obj.servo(4, i);
    currentAnalogVal = obj.getAverageData('analog', 5);
    pause(0.1);
    highTresh = 0;
    lowTresh = 0;
    if( i < 50)
        highTresh =  (previousAnalogVal + 0.02);
        lowTresh =  (previousAnalogVal - 0.02);
    else
        highTresh =  (previousAnalogVal + 10);
        lowTresh =  (previousAnalogVal - 10);
    end
    if( (currentAnalogVal(2) <= highTresh ) && (currentAnalogVal(2)>= lowTresh ) )
        try
            %s 47 i 140, m 35 i 110 , B 23 i 80
            if (i <= 80 )
                obj.servo(4, i - 23); %s 47 m 35 , B 23
                disp('Big')
                size = i - 23;
%                 size = 1;
                break;
            elseif(i > 80 && i < 115)
                obj.servo(4, i - 30);
                disp('Medium')
                size = i - 30;
%                 size = 0.5;
                break;
            else
                obj.servo(4, i - 25);
                disp('Small')
                size = i - 25;
%                 size = 0;
                break;
            end
        catch
            disp('not the end yet')
        end
    end

    previousAnalogVal = currentAnalogVal(2);
    pause(0.5);
end
obj.servo(4, 0);
end

function NewMins = CalcNewMins(readings, previousVals)
tempVals = zeros(3,1);
for i = 1:5
    if(readings(i, 1) < previousVals(i, 1))
        tempVals(i, 1) = readings(i, 1);
    else
        tempVals(i, 1) = previousVals(i ,1);
    end
end
NewMins = tempVals;
end

function NewMaxs = CalcNewMaxs(readings, previousVals)
tempVals = zeros(3,1);
for i = 1:5
    if(readings(i, 1) > previousVals(i, 1))
        tempVals(i, 1) = readings(i, 1);
    else
        tempVals(i, 1) = previousVals(i ,1);
    end
end
NewMaxs = tempVals;
end