function varargout = RACS_ver1(varargin)
% RACS_VER1 MATLAB code for RACS_ver1.fig
%      RACS_VER1, by itself, creates a new RACS_VER1 or raises the existing
%      singleton*.
%
%      H = RACS_VER1 returns the handle to a new RACS_VER1 or the handle to
%      the existing singleton*.
%
%      RACS_VER1('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in RACS_VER1.M with the given input arguments.
%
%      RACS_VER1('Property','Value',...) creates a new RACS_VER1 or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before RACS_ver1_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to RACS_ver1_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help RACS_ver1

% Last Modified by GUIDE v2.5 03-Mar-2020 14:13:42

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @RACS_ver1_OpeningFcn, ...
                   'gui_OutputFcn',  @RACS_ver1_OutputFcn, ...
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


% --- Executes just before RACS_ver1 is made visible.
function RACS_ver1_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to RACS_ver1 (see VARARGIN)

% Choose default command line output for RACS_ver1

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
Motor=serial('COM2');           % Check COM port for the use in other systems
Motor.Terminator = 'CR';
fopen(Motor);
fprintf(Motor,'mode=1');
fprintf(Motor,'ens');           % open the laser shutter 1 as a default

% Call & open the optical shutter 2 (for 532 nm laser)
Motor2=serial('COM6');          % Check COM port for the use in other systems
Motor2.Terminator = 'CR';
fopen(Motor2);
fprintf(Motor2,'mode=1');
fprintf(Motor2,'ens');          % open the laser shutter 2 as a default

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes RACS_ver1 wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = RACS_ver1_OutputFcn(hObject, eventdata, handles) 
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

% Version 3 modification
% the equation for PL value calculation has been modified so that the
% system works with Zeiss water-immersion objective
% PL = I(2040-2300)-I(1850-1900)

global LabSpec Motor Motor2 Mode IntegrationTime AccumulationNum_2 AcqFrom AcqTo
global Dis_lower Dis_upper Crit_lower Crit_upper CD_lower CD_upper sum_Dis
global loopFlag threshold_1 threshold_2 A

loopFlag = true;
threshold_1 = 1.1;          % threshold to identify the cell in the optical tweezers (note: 1.1)
threshold_2 = 100;          % threshold to distinguish between labelled and unlabelled cells

% Generate the output file
datetime = datestr(clock, 31);
datetime = strrep(datetime,':','_');               % Replace colon with underscore
filename1 = ['Spectra_Labeled_' datetime '.txt'];
filename2 = ['Spectra_Unlabeled_' datetime '.txt'];
filename3 = ['PCPL_Labeled_' datetime '.txt'];
filename4 = ['PCPL_Unlabeled_' datetime '.txt'];

fp=fopen(filename1,'a+');
fprintf(fp,'Raman_shift(cm-1) ');
fprintf(fp,'%f ',A);
fprintf(fp,'\n');

fp2=fopen(filename2,'a+');
fprintf(fp2,'Raman_shift(cm-1) ');
fprintf(fp2,'%f ',A);
fprintf(fp2,'\n');

fp3=fopen(filename3,'a+');
fprintf(fp3,'Cell# PC PL \n');

fp4=fopen(filename4,'a+');
fprintf(fp4,'Cell# PC PL \n');

fprintf(Motor,'ens');
pause(1.0)
fprintf(Motor,'ens');

IniPositionY = 0;
PositionToGoY = 270;             % Move the stage 270 um in y-direction
   
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
            % Calculation of I(2040-2300 cm-1)/I(1850-1900 cm-1) = CD / reference
            sum_CD = 0.0;
            sum_Crit = 0.0;
            base = 0.0;
            for i = CD_lower:CD_upper
                sum_CD = sum_CD + (D(i)-base);
            end
            for j = Crit_lower:Crit_upper
                sum_Crit = sum_Crit + (D(j)-base);
            end
            
            ratio_2 = sum_CD/sum_Crit;
            set(handles.Threshold_target_output,'String',ratio_2);
            
            result_1 = str2num(get(handles.Result_1,'String'))+1;
            set(handles.Result_1,'String',result_1);        % counting the analyzed cell
            
            % optical shutter operations
            % if the cell is the good cell, move the stage perpendicular 
            % to the flow direction and release the cell.
            % otherwise, release the cell at the streamline to the waste outlet.
            
            if ratio_2 >= threshold_2                       % in case labeled cell
                fprintf(Motor2,'ens');
                Ret = LabSpec.MoveMotor('Y',PositionToGoY,'',0);        % 'Horiba-specific': move the stage to sample-free region
                set(handles.Stage_y,'String',PositionToGoY);
                pause(0.1)
                fprintf(Motor,'ens');
                Ret = LabSpec.MoveMotor('Y',IniPositionY,'',0);         % 'Horiba-specific': move the stage back to sample region
                set(handles.Stage_y,'String',IniPositionY);
                
                % Update the Results window and write a datum
                result_2 = str2num(get(handles.Result_2,'String'))+1;
                set(handles.Result_2,'String',result_2);
                
                fprintf(fp,'cell#_%d ',result_2);
                fprintf(fp,'%f ',D);
                fprintf(fp,'\n');
                fprintf(fp3,'%d %f %f \n',result_2,ratio,ratio_2);
                
                fprintf(Motor,'ens');
                fprintf(Motor2,'ens');
            else                                             % in case unlabeled cell
                fprintf(Motor,'ens');
                
                % Update the Results window and write a datum
                result_3 = str2num(get(handles.Result_3,'String'))+1;
                set(handles.Result_3,'String',result_3);
                fprintf(fp2,'cell#_%d ',result_3);
                fprintf(fp2,'%f ',D);
                fprintf(fp2,'\n');
                fprintf(fp4,'%d %f %f \n',result_3,ratio,ratio_2);
                
                pause(0.2)
                fprintf(Motor,'ens');
            end
            % Update the Results window
            result_2 = str2num(get(handles.Result_2,'String'));
            result_4 = result_2./result_1;
            set(handles.Result_4,'String',result_4);
                                    
            % Draw the figure in lower window
            axes(handles.Label_2);
            plot(A, D, 'b-', 'LineWidth', 1)
            legend(sprintf('Acquisition time = %.2f s',IntegrationTime))
            title('Measured spectra')
            xlabel('Raman shift (cm-1)')
            ylabel('Intensity (AU)')
            axis([400 3300 -inf inf])
            grid on
            break
        end
        pause(0.0001)
    end
    
    pause(0.0001)
    if(loopFlag == false)
        break;
        fclose(fp);
        fclose(fp2);
        fclose(fp3);
        fclose(fp4);
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

hf = findobj('Name','gui');
close(hf)

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
Ret = LabSpec.Video(0);             % 'Horiba-specific': turn on the video


% --- Executes on button press in Video_off.
function Video_off_Callback(hObject, eventdata, handles)
% hObject    handle to Video_off (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global LabSpec
Ret = LabSpec.Video(1);             % 'Horiba-specific': turn off the video


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
global LabSpec Mode IntegrationTime AccumulationNum AccumulationNum_2 AcqFrom AcqTo
global A Motor
Mode = 10;                  % ACQ_SPECTRUM + ACQ_AUTO_SHOW
IntegrationTime = 0.3;      % 0.3 s
AccumulationNum = 10;       % accumulations = 10 ; averaging the 10 spectra
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
LabSpec.Acq(Mode,IntegrationTime,AccumulationNum,AcqFrom,AcqTo);        % 'Horiba-specific': measure the Raman spectrum with five parameters (see above)
while SpectrumID <= 0
    SpectrumID = LabSpec.GetAcqID();                                    % 'Horiba-specific': identify the ID of the measured spectrum
end
SpectrumValues = LabSpec.GetValueSimple(SpectrumID,'XYData',0,5);       % 'Horiba-specific': place the measured datum onto the variable 'SpectrumValues'

A = (cell2mat(SpectrumValues(1,:)))';
B = (cell2mat(SpectrumValues(2,:)))';

% Three spectral regions to calculate PC and PL
% Dis (1,620-1,670 cm-1); Crit (1,850-1,900 cm-1); CD (2,040-2,300 cm-1)
% This part can be adjusted depending on spectral region of interest
[M N] = size(A);
global Dis_lower Dis_upper Crit_lower Crit_upper CD_lower CD_upper sum_Dis;

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

for i=1:M
    if A(i) > 1850
        Crit_lower = i;
        break
    end
end

for i=1:M
    if A(i) > 1900
        Crit_upper = i-1;
        break
    end
end

for i=1:M
    if A(i) > 2040
        CD_lower = i;
        break
    end
end

for i=1:M
    if A(i) > 2300
        CD_upper = i-1;
        break
    end
end

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
Ret = LabSpec.MoveMotor('Y',IniPositionY,'',0);         % 'Horiba-specific': move the stage back to sample region


% --- Executes on button press in Stop.
function Stop_Callback(hObject, eventdata, handles)
% hObject    handle to Stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global loopFlag

loopFlag = false;


function Threshold_cell_input_Callback(hObject, eventdata, handles)
% hObject    handle to Threshold_cell_input (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of Threshold_cell_input as text
%        str2double(get(hObject,'String')) returns contents of Threshold_cell_input as a double

global threshold_1 Motor
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

global threshold_2 Motor
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
