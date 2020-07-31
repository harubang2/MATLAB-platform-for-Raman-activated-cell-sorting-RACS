function varargout = RACS_ver2(varargin)
% RACS_VER2 MATLAB code for RACS_ver2.fig
%      RACS_VER2, by itself, creates a new RACS_VER2 or raises the existing
%      singleton*.
%
%      H = RACS_VER2 returns the handle to a new RACS_VER2 or the handle to
%      the existing singleton*.
%
%      RACS_VER2('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RACS_VER2.M with the given input arguments.
%
%      RACS_VER2('Property','Value',...) creates a new RACS_VER2 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before RACS_ver2_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to RACS_ver2_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help RACS_ver2

% Last Modified by GUIDE v2.5 28-Feb-2020 18:21:15

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @RACS_ver2_OpeningFcn, ...
                   'gui_OutputFcn',  @RACS_ver2_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before RACS_ver2 is made visible.
function RACS_ver2_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to RACS_ver2 (see VARARGIN)

% Choose default command line output for RACS_ver2

handles.output = hObject;

axes(handles.Lab_logo);
imshow('Logo.jpg');

axes(handles.ETH_logo);
imshow('ETH_logo.jpg');

% Call the LabSpec ActiveX
global LabSpec
LabSpec = actxcontrol('NFACTIVEX.NFActiveXCtrl.1', [15 15 410 390]);        % build a bridge between LabSpec and MATLAB

% Call & open the optical shutter 1 (for 532 & 1064 nm lasers)
global Motor Motor2
Motor=serial('COM2');           % Check COM port for the use in other system
Motor.Terminator = 'CR';
fopen(Motor);
fprintf(Motor,'mode=1');
fprintf(Motor,'ens');           % open the laser shutter 1 as a default

% Call & open the optical shutter 2 (for 532 nm laser)
Motor2=serial('COM6');          % Check COM port for the use in other system 
Motor2.Terminator = 'CR';
fopen(Motor2);
fprintf(Motor2,'mode=1');
fprintf(Motor2,'ens');          % open the laser shutter 2 as a default

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes RACS_ver2 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = RACS_ver2_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in togglebutton1.
function togglebutton1_Callback(hObject, eventdata, handles)
% hObject    handle to togglebutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of togglebutton1


% --- Executes on button press in Start_the_process.
function Start_the_process_Callback(hObject, eventdata, handles)
% hObject    handle to Start_the_process (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Version_8 modification
% K-mean clustering algorithm was employed for the sorting.

global LabSpec Motor Motor2 Mode IntegrationTime AccumulationNum_2 AcqFrom AcqTo
global Dis_lower Dis_upper sum_Dis
global loopFlag threshold_1 threshold_2 A ROI

loopFlag = true;
threshold_1 = 1.1;          % threshold to identify the cell in the optical tweezers (note: 1.1)
threshold_2 = 1;            % threshold to identify the cell with the high cytochrome intensity (note: 1 means most upper K-cluster)

set(handles.Threshold_cell_input,'String',threshold_1);

% Generate the output file
datetime = datestr(clock, 31);
datetime = strrep(datetime,':','_');               % Replace colon with underscore
filename1 = ['RACS_Spectra_Selected_' datetime '.txt'];
filename2 = ['RACS_Spectra_Rejected_' datetime '.txt'];
filename3 = ['RACS_PC_Selected_' datetime '.txt'];
filename4 = ['RACS_PC_Rejected_' datetime '.txt'];
filename5 = ['RACS_Spectra_Clustering_' datetime '.txt'];
filename6 = ['RACS_Summary_Clustering_' datetime '.txt'];

fp=fopen(filename1,'a+');
fprintf(fp,'Raman_shift(cm-1) ');
fprintf(fp,'%f ',A);
fprintf(fp,'\n');

fp2=fopen(filename2,'a+');
fprintf(fp2,'Raman_shift(cm-1) ');
fprintf(fp2,'%f ',A);
fprintf(fp2,'\n');

fp3=fopen(filename3,'a+');
fprintf(fp3,'Cell# PC_input PC K-cluster_in K-cluster_out\n');

fp4=fopen(filename4,'a+');
fprintf(fp4,'Cell# PC_input PC K-cluster_in K-cluster_out\n');

fp6=fopen(filename6,'a+');

% Open the file that contains the data for the initial clustering
[FileName,PathName] = uigetfile('*.txt','browse');
delimiterIn = ' ';
headerlinesIn = 1;
D_imported = importdata(FileName,delimiterIn,headerlinesIn);

R_s = cellfun(@str2num,D_imported.textdata(1,2:end));
cell_num = D_imported.textdata(2:end,1);
y = [];
y = D_imported.data;

fp5=fopen(filename5,'a+');
fprintf(fp5,'Raman_shift(cm-1) ');
fprintf(fp5,'%f ',R_s);
fprintf(fp5,'\n');
for i=1:size(y,1)
    fprintf(fp5,'%s ',cell_num(i));
    fprintf(fp5,'%f ',y(i,:));
    fprintf(fp5,'\n');
end
fclose(fp5);

y(:, A<ROI(1) | ROI(2)<A & A<ROI(3) | ROI(4)<A & A<ROI(5) | ROI(6)<A & A<ROI(7) | A>ROI(8)) = [];

% Conduct the K-means clustering
for k=2:10
    rng('default')          % for reproducibility of the K-mean clustering results
    [IDX, cent] = kmeans(y,k);
    cent_2 = cent(:,1);
    outer_cent = find(ismember(cent_2,max(cent_2)))
    outer_cent_2 = find(ismember(cent_2,max(cent_2(cent_2<max(cent_2)))))
    B1 = find(IDX==outer_cent);
    B2 = find(IDX==outer_cent_2);
    if k > 2
        if size(old_B1,1) == size(B1,1)
            k = k-1;
            rng('default')      % for reproducibility of the K-means clustering results
            [IDX, cent] = kmeans(y,k);
            cent_2 = cent(:,1);
            outer_cent = find(ismember(cent_2,max(cent_2)));
            outer_cent_2 = find(ismember(cent_2,max(cent_2(cent_2<max(cent_2)))));
            B1 = find(IDX==outer_cent);
            B2 = find(IDX==outer_cent_2);
            break;
        end
    end
    old_B1 = B1;
end

fprintf(fp6,'# of clusters = %d \n',k);
fprintf(fp6,'Cell# in outermost cluster:');
fprintf(fp6,'%d ',B1');
fprintf(fp6,'\n');
fprintf(fp6,'Cell# in 2nd outermost cluster:');
fprintf(fp6,'%d ',B2');
fprintf(fp6,'\n');
fclose(fp6);

IniPositionY = 0;
PositionToGoY = 270;             % Move the stage 270 um in y-direction

result_1 = 0;
result_2 = 0;
result_3 = 0;
result_4 = 0;
set(handles.Result_1,'String',result_1);
set(handles.Result_2,'String',result_2);
set(handles.Result_3,'String',result_3);
set(handles.Result_4,'String',result_4);

fprintf(Motor,'ens');
pause(1.0)
fprintf(Motor,'ens');

% Start the real sorting
while true
    while true
        pause(0.0001)
        if(loopFlag == false)
            break;
        end
        LabSpec.Acq(Mode,IntegrationTime,AccumulationNum_2,AcqFrom,AcqTo);      % 'Horiba-specific': measure the Raman spectrum with five parameters (see below)
        SpectrumID = -3;
        while SpectrumID <= 0
            SpectrumID = LabSpec.GetAcqID();                                    % 'Horiba-specific': identify the ID of the measured spectrum
        end
        SpectrumValues = LabSpec.GetValueSimple(SpectrumID,'XYData',0,5);       % 'Horiba-specific': place the measured datum onto the variable 'SpectrumValues'
        D = cell2mat(SpectrumValues(2,:)');
        sum_Dis2 = 0.0;
        for i=Dis_lower:Dis_upper
            sum_Dis2 = sum_Dis2 + D(i);
        end
        ratio = sum_Dis2/sum_Dis;
        set(handles.Threshold_cell_output,'String',ratio);
        
        if ratio > threshold_1
            result_1 = str2num(get(handles.Result_1,'String'))+1;
            set(handles.Result_1,'String',result_1);
                
            D_2 = D;
            D_2(A<ROI(1) | ROI(2)<A & A<ROI(3) | ROI(4)<A & A<ROI(5) | ROI(6)<A & A<ROI(7) | A>ROI(8)) = [];
                
            for N=1:k
                dist(N) = norm(D_2-cent(N,:)');
            end
                
            [distance, predicted] = min(dist,[],2);         % calculate the Euclidean distance
                
            if threshold_2 == 1 && predicted == outer_cent         % if the uppermost cluster is the target
                fprintf(Motor2,'ens');
                K_value = 1;
                set(handles.Threshold_target_output,'String',K_value);
                Ret = LabSpec.MoveMotor('Y',PositionToGoY,'',0);            % 'Horiba-specific': move the stage to sample-free region
                set(handles.Stage_y,'String',PositionToGoY);
                pause(0.1)
                fprintf(Motor,'ens');
                Ret = LabSpec.MoveMotor('Y',IniPositionY,'',0);             % 'Horiba-specific': move the stage back to sample region
                set(handles.Stage_y,'String',IniPositionY);
                
                % Update the Results window and write a datum
                result_2 = str2num(get(handles.Result_2,'String'))+1;
                set(handles.Result_2,'String',result_2);
                
                fprintf(fp,'cell#_%d ',result_2);
                fprintf(fp,'%f ',D);
                fprintf(fp,'\n');
                fprintf(fp3,'%d %f %f %d %d \n',result_2,threshold_1,ratio,threshold_2,predicted);
                fprintf(Motor2,'ens');
                pause(0.1)
                fprintf(Motor,'ens');
            elseif threshold_2 == 2 && predicted == outer_cent     % if the uppermost and second uppermost is the target
                fprintf(Motor2,'ens');
                K_value = 1;
                set(handles.Threshold_target_output,'String',K_value);
                Ret = LabSpec.MoveMotor('Y',PositionToGoY,'',0);            % 'Horiba-specific': move the stage to sample-free region
                set(handles.Stage_y,'String',PositionToGoY);
                pause(0.1)
                fprintf(Motor,'ens');
                Ret = LabSpec.MoveMotor('Y',IniPositionY,'',0);             % 'Horiba-specific': move the stage back to sample region
                set(handles.Stage_y,'String',IniPositionY);
                
                % Update the Results window and write a datum
                result_2 = str2num(get(handles.Result_2,'String'))+1;
                set(handles.Result_2,'String',result_2);
                
                fprintf(fp,'cell#_%d ',result_2);
                fprintf(fp,'%f ',D);
                fprintf(fp,'\n');
                fprintf(fp3,'%d %f %f %d %d \n',result_2,threshold_1,ratio,threshold_2,predicted);
                fprintf(Motor2,'ens');
                pause(0.1)
                fprintf(Motor,'ens');
            elseif threshold_2 == 2 && predicted == outer_cent_2     % if the uppermost and second uppermost is the target
                fprintf(Motor2,'ens');
                K_value = 2;
                set(handles.Threshold_target_output,'String',K_value);
                Ret = LabSpec.MoveMotor('Y',PositionToGoY,'',0);            % 'Horiba-specific': move the stage to sample-free region
                set(handles.Stage_y,'String',PositionToGoY);
                pause(0.1)
                fprintf(Motor,'ens');
                Ret = LabSpec.MoveMotor('Y',IniPositionY,'',0);             % 'Horiba-specific': move the stage back to sample region
                set(handles.Stage_y,'String',IniPositionY);
                    
                % Update the Results window and write a datum
                result_2 = str2num(get(handles.Result_2,'String'))+1;
                set(handles.Result_2,'String',result_2);
                
                fprintf(fp,'cell#_%d ',result_2);
                fprintf(fp,'%f ',D);
                fprintf(fp,'\n');
                fprintf(fp3,'%d %f %f %d %d \n',result_2,threshold_1,ratio,threshold_2,predicted);
                fprintf(Motor2,'ens');
                pause(0.1)
                fprintf(Motor1,'ens');
            else                              % in case the waste cell
                fprintf(Motor,'ens');
                K_value = 'N/A';
                set(handles.Threshold_target_output,'String',K_value);
                
                % Update the Results window and write a datum
                result_3 = str2num(get(handles.Result_3,'String'))+1;
                set(handles.Result_3,'String',result_3);
                fprintf(fp2,'cell#_%d ',result_3);
                fprintf(fp2,'%f ',D);
                fprintf(fp2,'\n');
                fprintf(fp4,'%d %f %f %d %d \n',result_3,threshold_1,ratio,threshold_2,predicted);
                pause(0.3)
                fprintf(Motor,'ens');
            end
                
            % Update the Results window
            result_2 = str2num(get(handles.Result_2,'String'));
            result_4 = result_2./result_1;
            set(handles.Result_4,'String',result_4);
        end
        
        % Draw the figure in lower window
        axes(handles.Label_2);
        plot(A, D, 'b-', 'LineWidth', 1)
        legend(sprintf('Acquisition time = %.2f s',IntegrationTime))
        title(sprintf('Measured spectra cell# %d', count_cell))
        xlabel('Raman shift (cm-1)')
        ylabel('Intensity (AU)')
        axis([400 3300 -inf inf])
        grid on
        break;
    end
    pause(0.0001)
    if(loopFlag == false)
        fclose(fp);
        fclose(fp2);
        fclose(fp3);
        fclose(fp4);
        break;
    end
end
    
% --- Executes on button press in Exit.
function Exit_Callback(hObject, eventdata, handles)
% hObject    handle to Exit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

global LabSpec Motor Motor2
% Close & evacuate the optical shutter
fprintf(Motor,'ens');
fclose(Motor);
delete(Motor);

fprintf(Motor2,'ens');
fclose(Motor2);
delete(Motor2);

% Close & evacuate the LabSpec
delete(LabSpec);

Close(gui)

function Result_2_Callback(hObject, eventdata, handles)
% hObject    handle to Result_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Result_2 as text
%        str2double(get(hObject,'String')) returns contents of Result_2 as a double

% --- Executes during object creation, after setting all properties.
function Result_2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Result_2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Result_3_Callback(hObject, eventdata, handles)
% hObject    handle to Result_3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Result_3 as text
%        str2double(get(hObject,'String')) returns contents of Result_3 as a double

% --- Executes during object creation, after setting all properties.
function Result_3_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Result_3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Result_4_Callback(hObject, eventdata, handles)
% hObject    handle to Result_4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Result_4 as text
%        str2double(get(hObject,'String')) returns contents of Result_4 as a double


% --- Executes during object creation, after setting all properties.
function Result_4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Result_4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function Result_1_Callback(hObject, eventdata, handles)
% hObject    handle to Result_1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Result_1 as text
%        str2double(get(hObject,'String')) returns contents of Result_1 as a double


% --- Executes during object creation, after setting all properties.
function Result_1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Result_1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function Stage_y_Callback(hObject, eventdata, handles)
% hObject    handle to Stage_y (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Stage_y as text
%        str2double(get(hObject,'String')) returns contents of Stage_y as a double


% --- Executes during object creation, after setting all properties.
function Stage_y_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Stage_y (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Video_on.
function Video_on_Callback(hObject, eventdata, handles)
% hObject    handle to Video_on (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LabSpec
Ret = LabSpec.Video(0);                     % 'Horiba-specific': turn on the video


% --- Executes on button press in Video_off.
function Video_off_Callback(hObject, eventdata, handles)
% hObject    handle to Video_off (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LabSpec
Ret = LabSpec.Video(1);                     % 'Horiba-specific': turn off the video


% --- Executes on mouse press over axes background.
function Label_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to Label (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes during object deletion, before destroying properties.
function Label_DeleteFcn(hObject, eventdata, handles)
% hObject    handle to Label (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes during object creation, after setting all properties.
function Label_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Label (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate Label


% --- Executes on button press in Spectra_calibration.
function Spectra_calibration_Callback(~, eventdata, handles)
% hObject    handle to Spectra_calibration (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Acquire the Spectra for the initialization (5 times average)
global LabSpec Mode IntegrationTime AccumulationNum_2 AcqFrom AcqTo;
global A Motor ROI;
global Dis_lower Dis_upper sum_Dis;

Mode = 10;                  % ACQ_SPECTRUM + ACQ_AUTO_SHOW
IntegrationTime = 0.3;      % 0.3 s
AccumulationNum = 10;       % accumulations = 10 ; averaging over 10 spectra
AccumulationNum_2 = 1;
AcqFrom = LabSpec.ConvertUnit(400,0);
AcqTo = LabSpec.ConvertUnit(3300,0);        % 'Horiba-specific': set the spectral window between 400-3300 cm-1

IniPositionY = 0;
PositionToGoY = 70;
fprintf(Motor,'ens');
pause(0.5)
Ret = LabSpec.MoveMotor('Y',PositionToGoY,'',0);        % 'Horiba-specific': move the stage 70 um in y-direction
set(handles.Stage_y,'String',PositionToGoY);
fprintf(Motor,'ens');
pause(1.0)

SpectrumID = -3;
LabSpec.Acq(Mode,IntegrationTime,AccumulationNum,AcqFrom,AcqTo);    % 'Horiba-specific': measure the Raman spectrum with five parameters (see above)
while SpectrumID <= 0
    SpectrumID = LabSpec.GetAcqID();                                % 'Horiba-specific': identify the ID of the measured spectrum
end
SpectrumValues = LabSpec.GetValueSimple(SpectrumID,'XYData',0,5);   % 'Horiba-specific': place the measured datum onto the variable 'SpectrumValues'

A = (cell2mat(SpectrumValues(1,:)))';
B = (cell2mat(SpectrumValues(2,:)))';

% Calculate the Discriminant region
% Note, Discriminant (1620-1670 cm-1)
[M N] = size(A);

for i=1:M
    if A(i) > 1620
        Dis_lower = i;
        break
    end
end

for i=1:M
    if A(i) > 1670
        Dis_upper = i-1;
        break
    end
end

sum_Dis = 0;
for i=Dis_lower:Dis_upper
    sum_Dis = sum_Dis + B(i);
end

% Spectral region of interest to be used for K-means clustering
ROI = [745;755;1122;1132;1309;1319;1580;1590];

datetime = datestr(clock, 31);
datetime = strrep(datetime,':','_');                % Replace colon with underscore
filename = ['Calibration_' datetime '.l6s'];
Ret = LabSpec.Save(SpectrumID,filename,'l6s');      % 'Horiba-specific': save the calibration spectrum

% Plot the calibration spectrum
axes(handles.Label);
plot(A, B, 'r-', 'LineWidth', 1)
legend(sprintf('Acquisition time = %.2f s', IntegrationTime))
title(sprintf('Calibration spectrum (averaged over %d measurements)', AccumulationNum))
xlabel('Raman shift (cm-1)')
ylabel('Intensity (AU)')
axis([400 3300 -inf inf])
grid on

set(handles.Stage_y,'String',IniPositionY);
Ret = LabSpec.MoveMotor('Y',IniPositionY,'',0);     % 'Horiba-specific': move the stage back to sample region


% --- Executes on button press in Stop.
function Stop_Callback(hObject, eventdata, handles)
% hObject    handle to Stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global loopFlag;

loopFlag = false;


function Threshold_cell_input_Callback(hObject, eventdata, handles)
% hObject    handle to Threshold_cell_input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Threshold_cell_input as text
%        str2double(get(hObject,'String')) returns contents of Threshold_cell_input as a double

global threshold_1 Motor;
threshold_1 = str2double(get(handles.Threshold_cell_input,'String'));
fprintf(Motor,'ens');
pause(0.2)
fprintf(Motor,'ens');


% --- Executes during object creation, after setting all properties.
function Threshold_cell_input_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Threshold_cell_input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function Threshold_target_input_Callback(hObject, eventdata, handles)
% hObject    handle to Threshold_target_input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Threshold_target_input as text
%        str2double(get(hObject,'String')) returns contents of Threshold_target_input as a double

global threshold_2 Motor;
threshold_2 = str2double(get(handles.Threshold_target_input,'String'));
fprintf(Motor,'ens');
pause(0.2)
fprintf(Motor,'ens');

% --- Executes during object creation, after setting all properties.
function Threshold_target_input_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Threshold_target_input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Threshold_cell_output_Callback(hObject, eventdata, handles)
% hObject    handle to Threshold_cell_output (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Threshold_cell_output as text
%        str2double(get(hObject,'String')) returns contents of Threshold_cell_output as a double


% --- Executes during object creation, after setting all properties.
function Threshold_cell_output_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Threshold_cell_output (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function Threshold_target_output_Callback(hObject, eventdata, handles)
% hObject    handle to Threshold_target_output (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Threshold_target_output as text
%        str2double(get(hObject,'String')) returns contents of Threshold_target_output as a double


% --- Executes during object creation, after setting all properties.
function Threshold_target_output_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Threshold_target_output (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --------------------------------------------------------------------
function uipushtool1_ClickedCallback(hObject, eventdata, handles)
% hObject    handle to uipushtool1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
datetime = datestr(clock, 31);
datetime = strrep(datetime,':','_');                % Replace colon with underscore
saveas(gcf,['Window_snapshot_' datetime '.bmp'])


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1


% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)AAA
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in Start_Clustering.
function Start_Clustering_Callback(hObject, eventdata, handles)
% hObject    handle to Start_Clustering (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LabSpec Motor Mode IntegrationTime AccumulationNum_2 AcqFrom AcqTo;
global Dis_lower Dis_upper sum_Dis;
global loopFlag threshold_1 A ROI;

loopFlag = true;
threshold_1 = 1.1;          % threshold to identify the cell in the optical tweezers (note: 1.1)
set(handles.Threshold_cell_input,'String',threshold_1);

datetime = datestr(clock, 31);
datetime = strrep(datetime,':','_');               % Replace colon with underscore
filename5 = ['Clustering_Spectra_' datetime '.txt'];
filename6 = ['Clustering_PC_' datetime '.txt'];
filename7 = ['Clustering_Summary_' datetime '.txt'];

fp5=fopen(filename5,'a+');
fprintf(fp5,'Raman_shift(cm-1) ');
fprintf(fp5,'%f ',A);
fprintf(fp5,'\n');

fp6=fopen(filename6,'a+');
fprintf(fp6,'Cell# PC_input PC\n');

fp7=fopen(filename7,'a+');

fprintf(Motor,'ens');
pause(1.0)
fprintf(Motor,'ens');

result_1 = 0;
set(handles.Result_1,'String',result_1);

while true
    while true
        pause(0.0001)
        if(loopFlag == false)
            break;
        end
        LabSpec.Acq(Mode,IntegrationTime,AccumulationNum_2,AcqFrom,AcqTo);  % 'Horiba-specific': measure the Raman spectrum with five parameters (see above)
        SpectrumID = -3;
        while SpectrumID <= 0
            SpectrumID = LabSpec.GetAcqID();            % 'Horiba-specific': identify the ID of the measured spectrum
        end
        SpectrumValues = LabSpec.GetValueSimple(SpectrumID,'XYData',0,5);   % 'Horiba-specific': place the measured datum onto the variable 'SpectrumValues'
        D = cell2mat(SpectrumValues(2,:)');
        sum_Dis2 = 0.0;
        for i=Dis_lower:Dis_upper
            sum_Dis2 = sum_Dis2 + D(i);
        end
        ratio = sum_Dis2/sum_Dis;
        set(handles.Threshold_cell_output,'String',ratio);
        
        if ratio > threshold_1
            result_1 = str2num(get(handles.Result_1,'String'))+1;
            set(handles.Result_1,'String',result_1);
            
            y(result_1,:) = D;
            fprintf(fp5,'cell#_%d ',result_1);
            fprintf(fp5,'%f ',D);
            fprintf(fp5,'\n');
            fprintf(fp6,'%d %f %f\n',result_1,threshold_1,ratio);
            fprintf(Motor,'ens');
            pause(0.5)
            fprintf(Motor,'ens');
        end
        pause(0.0001)
    end
    pause(0.0001)
    if(loopFlag == false)
        % select spectral region of interest to be used for K-means
        % clustering
        y(:, A<ROI(1) | ROI(2)<A & A<ROI(3) | ROI(4)<A & A<ROI(5) | ROI(6)<A & A<ROI(7) | A>ROI(8)) = [];

        % conduct K-means clustering
        for k=2:10
            rng('default')          % for reproducibility of the K-means clustering results
            [IDX, cent] = kmeans(y,k);
            cent_2 = cent(:,1);
            outer_cent = find(ismember(cent_2,max(cent_2)));
            outer_cent_2 = find(ismember(cent_2,max(cent_2(cent_2<max(cent_2)))));
            B1 = find(IDX==outer_cent);
            B2 = find(IDX==outer_cent_2);
            if k > 2
                if size(old_B1,1) == size(B1,1)
                    k = k-1;
                    rng('default')      % for reproducibility of the K-means clustering results
                    [IDX, cent] = kmeans(y,k);
                    cent_2 = cent(:,1);
                    outer_cent = find(ismember(cent_2,max(cent_2)));
                    outer_cent_2 = find(ismember(cent_2,max(cent_2(cent_2<max(cent_2)))));
                    B1 = find(IDX==outer_cent);
                    B2 = find(IDX==outer_cent_2);
                    
                    break;
                end
            end
            old_B1 = B1;
        end
        fprintf(fp7,'# of clusters = %d \n',k);
        fprintf(fp7,'Cell# in outermost cluster:');
        fprintf(fp7,'%d ',B1');
        fprintf(fp7,'\n');
        fprintf(fp7,'Cell# in 2nd outermost cluster:');
        fprintf(fp7,'%d ',B2');
        fprintf(fp7,'\n');
                        
        fclose(fp5);
        fclose(fp6);
        fclose(fp7);
        break;
    end
end
