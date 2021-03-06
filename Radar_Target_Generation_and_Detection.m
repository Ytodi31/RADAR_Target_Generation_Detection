clear all
clc;

%% Radar Specifications 
%%%%%%%%%%%%%%%%%%%%%%%%%%%
fc = 77e9;
rangeMax = 200;
rangeResolution = 1;
velocityMax = 100;
%%%%%%%%%%%%%%%%%%%%%%%%%%%

c = 3e8;

%% User Defined Range and Velocity of target
% *%TODO* :
% define the target's initial position and velocity. Note : Velocity
% remains contant
targetRange = 100;
targetVelocity = -20;


%% FMCW Waveform Generation

% *%TODO* :
%Design the FMCW waveform by giving the specs of each of its parameters.
% Calculate the Bandwidth (B), Chirp Time (Tchirp) and Slope (slope) of the FMCW
% chirp using the requirements above.
Bsweep = c/(2*rangeResolution);
chirpFactor = 5.5;
Tchirp = chirpFactor*2*rangeMax/c;
slope = Bsweep/Tchirp;

                                                          
%The number of chirps in one sequence. Its ideal to have 2^ value for the ease of running the FFT
%for Doppler Estimation. 
Nd=128;                   % #of doppler cells OR #of sent periods % number of chirps

%The number of samples on each chirp. 
Nr=1024;                  %for length of time OR # of range cells

% Timestamp for running the displacement scenario for every sample on each
% chirp
t=linspace(0,Nd*Tchirp,Nr*Nd); %total time for samples


%Creating the vectors for Tx, Rx and Mix based on the total samples input.
Tx=zeros(1,length(t)); %transmitted signal
Rx=zeros(1,length(t)); %received signal
Mix = zeros(1,length(t)); %beat signal

%Similar vectors for range_covered and time delay.
r_t=zeros(1,length(t));
td=zeros(1,length(t));


%% Signal generation and Moving Target simulation
% Running the radar scenario over the time. 

for i=1:length(t)         
    
   % *%TODO* :
    %For each time stamp update the Range of the Target for constant velocity. 
    r_t(i) = targetRange + targetVelocity*t(i);
    
    % *%TODO* :
    %For each time sample we need update the transmitted and
    %received signal. 
    Tx(i) = cos(2*pi*(fc*t(i) + (slope*t(i)^2)/2));
    td(i) = 2*r_t(i)/c;
    Rx(i) = cos(2*pi*(fc*(t(i)-td(i)) + slope*((t(i)-td(i))^2)/2));
    
    % *%TODO* :
    %Now by mixing the Transmit and Receive generate the beat signal
    %This is done by element wise matrix multiplication of Transmit and
    %Receiver Signal
    Mix(i) = Tx(i).*Rx(i);
    
end

%%
%signal_fft = fft(Mix);

 % *%TODO* :
%reshape the vector into Nr*Nd array. Nr and Nd here would also define the size of
%Range and Doppler FFT respectively.
signal_fft = reshape(Mix, [Nr, Nd]);
 % *%TODO* :
%run the FFT on the beat signal along the range bins dimension (Nr) and
%normalize.
signal_fft = fft(signal_fft, Nr);
 % *%TODO* :
% Take the absolute value of FFT output
l = length(signal_fft);
signal_fft = abs(signal_fft/l);

 % *%TODO* :
% Output of FFT is double sided signal, but we are interested in only one side of the spectrum.
% Hence we throw out half of the samples.
signal_fft = signal_fft(1:l/2-1);

%plotting the range
figure ('Name','Range from First FFT')
subplot(2,1,1)

 % *%TODO* :
 % plot FFT output 
plot(signal_fft, 'linewidth',2.5, 'color', 'r');
xlabel('Range(m)')
ylabel('Signal Strength')
title('Range estimation from FFT');

axis ([0 200 0 0.5]);



%% RANGE DOPPLER RESPONSE
% The 2D FFT implementation is already provided here. This will run a 2DFFT
% on the mixed signal (beat signal) output and generate a range doppler
% map.You will implement CFAR on the generated RDM


% Range Doppler Map Generation.

% The output of the 2D FFT is an image that has reponse in the range and
% doppler FFT bins. So, it is important to convert the axis from bin sizes
% to range and doppler based on their Max values.

Mix=reshape(Mix,[Nr,Nd]);

% 2D FFT using the FFT size for both dimensions.
sig_fft2 = fft2(Mix,Nr,Nd);

% Taking just one side of signal from Range dimension.
sig_fft2 = sig_fft2(1:Nr/2,1:Nd);
sig_fft2 = fftshift (sig_fft2);
RDM = abs(sig_fft2);
RDM = 10*log10(RDM) ;

%use the surf function to plot the output of 2DFFT and to show axis in both
%dimensions
doppler_axis = linspace(-100,100,Nd);
range_axis = linspace(-200,200,Nr/2)*((Nr/2)/400);
figure,surf(doppler_axis,range_axis,RDM);

%% CFAR implementation

%Slide Window through the complete Range Doppler Map
[R,D] = size(RDM)
% *%TODO* :
%Select the number of Training Cells in both the dimensions.
Tr = 8;
Td = 4;
% *%TODO* :
%Select the number of Guard Cells in both dimensions around the Cell under 
%test (CUT) for accurate estimation
Gr = 4;
Gd = 2;
% *%TODO* :
% offset the threshold by SNR value in dB
offset = 1.4;

% *%TODO* :
%Create a vector to store noise_level for each iteration on training cells
noise_level = zeros(size(RDM));

CFAROutput = zeros(size(RDM));
% *%TODO* :
%design a loop such that it slides the CUT across range doppler map by
%giving margins at the edges for Training and Guard Cells.
%For every iteration sum the signal level within all the training
%cells. To sum convert the value from logarithmic to linear using db2pow
%function. Average the summed values for all of the training
%cells used. After averaging convert it back to logarithimic using pow2db.
%Further add the offset to it to determine the threshold. Next, compare the
%signal under CUT with this threshold. If the CUT level > threshold assign
%it a value of 1, else equate it to 0.
grid_size = (2*(Tr+Gr)+1)*(2*(Td+Gd)+1);
guard_region = (2*Gr+1)*(2*Gd+1);
training_region = grid_size - guard_region;
for i=1:(R-2*(Tr+Gr+1))
    for j = 1:(D-2*(Td+Gd+1))       
        gridRDM = RDM(i:i+2*(Tr+Gr), j:j+2*(Td+Gd));
        gridRDM(Tr:Tr+2*Gr, Td:Td+2*Gd) = 0;
        tempRDM = db2pow(gridRDM);
        tempRDM = sum(tempRDM(:));
        noise_level(i,j) = pow2db(tempRDM/training_region);
        thresholdCFAR = offset*noise_level(i,j);
        signalCFAR = RDM(i+Tr+Gr, j+Td+Gd);        
        if(signalCFAR>thresholdCFAR)
            CFAROutput(i,j) = 1;
        end
    end
end

   % Use RDM[x,y] as the matrix from the output of 2D FFT for implementing
   % CFAR


% *%TODO* :
% The process above will generate a thresholded block, which is smaller 
%than the Range Doppler Map as the CUT cannot be located at the edges of
%matrix. Hence,few cells will not be thresholded. To keep the map size same
% set those values to 0. 

% [rows, cols] = size(RDM);
% for i = 1:rows
%     for j =1:cols
%         if(CFAROutput(i,j) >1 )
%            CFAROutput(i,j) =0;
%         end
%     end
% end

%display the CFAR output using the Surf function like we did for Range
%Doppler Response output.

figure,surf(doppler_axis,range_axis, CFAROutput);
colorbar;
xlabel('doppler'); ylabel('range');
title('CFAR output');
