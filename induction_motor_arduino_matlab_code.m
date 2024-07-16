clc;
clear all;

% Configure Arduino
a = arduino('COM10', 'Uno'); 
% Analog pin connected to the current sensor
pin = 'A0'; 

% Creating a video input object
vid = videoinput('winvideo', 1, 'RGB24_1280x720');

% Setting the video input object's properties
src = getselectedsource(vid);
src.ExposureMode = 'manual';
src.Exposure = -4; % Adjusting the exposure as needed

% Creating a figure for displaying the video stream
figure;
hImage = imshow(zeros(720, 1280, 3));

% Main loop
while true
        % Read current sensor data from Arduino
        sensor_value = readVoltage(a, pin)*5/1023;
        current = (sensor_value - 2.5) /0.100; 

    % Displaying the video stream
    start(vid);
    % Get a frame from the camera
    frame = getsnapshot(vid);
    
    % Display the frame
    set(hImage, 'CData', frame);
    drawnow;

    % Perform wavelet decomposition
    [c, l] = wavedec(current, 8, 'db44');
    approximation = appcoef(c, l, 'db44');
    [d1, d2, d3, d4, d5, d6, d7, d8] = detcoef(c, l, [1 2 3 4 5 6 7 8]);
    subplot(9, 1, 1)
    plot(approximation);
    title('Approximation at Level 3')
    subplot(9, 1, 2)
    plot(d1)
    title('Detail Coefficients at Level 1');
    subplot(9, 1, 3)
    plot(d2)
    title('Detail Coefficients at Level 2');
    subplot(9, 1, 4)
    plot(d3)
    title('Detail Coefficients at Level 3');
    subplot(9, 1, 5)
    plot(d4)
    title('Detail Coefficients at Level 4');
    subplot(9, 1, 6)
    plot(d5)
    title('Detail Coefficients at Level 5');
    subplot(9, 1, 7)
    plot(d6)
    title('Detail Coefficients at Level 6');
    subplot(9, 1, 8)
    plot(d7)
    title('Detail Coefficients at Level 7');
    subplot(9, 1, 9)
    plot(d8)
    title('Detail Coefficients at Level 8');

    % Compute feature parameters for each detailed coefficient
    % 8 coefficients and 5 feature parameters (energy, standard deviation, RMS value, skewness, variance)
    feature_parameters = zeros(8, 5); 

    for i = 1:8
        % Calculating feature parameters for each detail coefficient
        energy = sum(d{i}.^2) / length(d{i});
        std_dev = std(d{i});
        rms_value = rms(d{i});
        skewness_val = skewness(d{i});
        variance_val = var(d{i});
        
        % Storing feature parameters in the matrix
        feature_parameters(i, :) = [energy, std_dev, rms_value, skewness_val, variance_val];
    end

    % Calculating fault indexing parameter (FIP)
    FIP = feature_parameters ./ feature_parameters(1,:); % Divide by healthy feature parameters

    % Configuring ANN
    hiddenLayers = 6;
    net = feedforwardnet(hiddenLayers);

    % Importing the trained model from Jupyter Notebook
    % Assuming X_train is your input data and Y_train is your target labels
    % Define the neural network architecture
    inputSize = size(X_train, 1); % Size of input data
    hiddenLayers = [16 32 64 64 32 16]; % Number of neurons in each hidden layer
    outputSize = size(Y_train, 1); % Size of output data

    % Create the neural network
    net = feedforwardnet(hiddenLayers);

    options = trainingOptions('adam', ... % Optimization algorithm
        'MaxEpochs', 100, ... % Maximum number of epochs
        'MiniBatchSize', 32, ... % Mini-batch size
        'Verbose', true, ... % Display training progress
        'Plots', 'training-progress'); % Plot training progress

    trainedNet = trainNetwork(X_train, Y_train, layers, options);

    % Using the trained ANN to predict faults

    predicted_fault = net(X_test);

    % Threshold for fault detection
    threshold = 0.5;

    % Determining fault presence based on the predicted output
    % For example, if the output is greater than the threshold, classify it as a fault
    % otherwise, classify it as healthy
    is_fault = predicted_fault > threshold;

    vibration_data = readDigitalPin(a, 'D2');

    if vibration_data > 0.5
        % Vibration is detected, trip the relay
        disp('Vibration detected. Tripping the relay.');
        writeDigitalPin(a, 'D7', 1);
    else
        % No vibration detected, do nothing
        disp('No vibration detected.');
    end

    % Displaying the results
    disp('Predicted fault status:');
    disp(is_fault);

    if any(is_fault)
        % Fault is detected, trip the relay
        disp('Fault detected. Tripping the relay.');
        writeDigitalPin(a, 'D7', 1);
    else
        % No fault detected, do nothing
        disp('No fault detected.');
    end

    % Disconnect from Arduino
    clear a;

    % Stop the video stream and clean up
    stop(vid);
    delete(vid);
    clear vid;

end
