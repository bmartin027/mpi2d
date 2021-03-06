function varargout = auto_segmentation(varargin)
% AUTO_SEGMENTATION M-file for auto_segmentation.fig
%      AUTO_SEGMENTATION, by itself, creates a new AUTO_SEGMENTATION or raises the existing
%      singleton*.
%
%      H = AUTO_SEGMENTATION returns the handle to a new AUTO_SEGMENTATION or the handle to
%      the existing singleton*.
%
%      AUTO_SEGMENTATION('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in AUTO_SEGMENTATION.M with the given input arguments.
%
%      AUTO_SEGMENTATION('Property','Value',...) creates a new AUTO_SEGMENTATION or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before auto_segmentation_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to auto_segmentation_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help auto_segmentation

% Last Modified by GUIDE v2.5 08-Oct-2010 10:39:39

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @auto_segmentation_OpeningFcn, ...
                   'gui_OutputFcn',  @auto_segmentation_OutputFcn, ...
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


% --- Executes just before auto_segmentation is made visible.
function auto_segmentation_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to auto_segmentation (see VARARGIN)

% Choose default command line output for auto_segmentation
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes auto_segmentation wait for user response (see UIRESUME)
% uiwait(handles.figure1);

%use varargin as command line arguments
%varargin(1): filename or matrix
%varargin(2): automated_bool
%varargin(3): LVcontour
%varargin(4): epicontour
%varargin(5): endocontour
global v
if(length(varargin)<1)
    varargin = {'cinemri1.study57000.slice2.mat'};
end
v.mutex = 1;
v.StartAngle = 0;
if(size(varargin{1},3) == 1)
    v.filename = char(varargin{1});
    %series and slice extraction
    i1 = findstr(v.filename,'.study');
    i2 = findstr(v.filename,'.slice');
    i3 = findstr(v.filename,'.mat');
    v.series = str2num(v.filename((i1+6):(i2-1)));
    v.slice = str2num(v.filename((i2+6):(i3-1)));
    
    load(v.filename);
    if(exist('imgrr'))
        v.data = imgrr;
    elseif(exist('cinemri'))
        v.data = cinemri;
    elseif(exist('cinemri1'))
        v.data = cinemri1;
    else
        disp(['I could not figure out what variable was contained in' varargin{1}]);
        return;
    end
    
    %% check for predone contours
    temp = pwd;
    if(~strcmp(temp((end-5):end),'Output'))
        cd('Output');
    end
        tmpname=['endo_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
        if(exist(tmpname))
            v.endo.boundary = load(tmpname);
            v.endo.boundary = v.endo.boundary(:,[2 1]);
        end
        tmpname=['epi_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
        if(exist(tmpname))
            v.epi.boundary = load(tmpname);
            v.epi.boundary = v.epi.boundary(:,[2 1]);
        end
        tmpname=['blood_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
        if(exist(tmpname))
            v.LV.boundary = load(tmpname);
            v.LV.boundary = v.LV.boundary(:,[2 1]);
        end
        tmpname = strcat('Roi_start_angle.study',int2str(v.series),'.slice',int2str(v.slice));
        if(exist(tmpname))
            v.StartAngle = load(tmpname);
            if(v.StartAngle > 2*pi)
                v.StartAngle = mod((v.StartAngle-90) * (2*pi)/360,2*pi);
            end
        end
    cd('..');
else
    v.data = varargin{1};
    v.series = [];
    v.slice = [];
end
[v.s1 v.s2 v.s3] = size(v.data);
% construct edges image
v.tedges = zeros(v.s1, v.s2);
v.handles = handles;
axes(handles.axes1);
% for t=1:v.s3
%     v.tedges = v.tedges + edge(v.data(:,:,t),'canny',[.05 .3]);
%     %imagesc(v.tedges); colormap gray
% end

v.variance = std(v.data(:,:,:),0,3);
v.tedges = v.variance;
v.t = 5;
v.r = 1;
v.waiting = 0;
v.overlays = 0;
v.DeletePressed = [0 0 0];
v.shift = 0;
v.control = 0;
v.alt = 0;
v.choosingStartAngle = 0;
v.power = 2;
v.threshold = 5;
v.stamping = 0;
v.stampType = 1;
v.type = 'endo';
v.curtype = 'Variance';
v.radius = 3;
v.mousePoint = [0 0];
v.theta = 1;
v.RightClickDown = 0;
v.LeftClickDown = 0;
v.workingimage = v.data(:,:,2);
v.shifts = zeros(v.s3,2);
set(handles.text1,'String','');
% should this be fully automated
v.auto = 0;
if(length(varargin)>1)
    v.auto = varargin{2};
end
%step by step construct contours
if(length(varargin)>2 || isfield(v,'LV'))
    if(length(varargin)>2)
        v.LV.boundary = varargin{3};
    end
    %reconstruct a mask
    v.LV.alpha = .1;
    v.LV.mask = roipoly(zeros(v.s1, v.s2)+1,v.LV.boundary(:,2),v.LV.boundary(:,1));
    v.LV.phi = [];
    [r c] = find(v.LV.mask);
    v.center = mean([r c]);
    i = find(c == floor(v.center(2)));
    r = r(i);
    c = c(i);
    [minr minri] = min(r);
    v.LV.boundary = bwtraceboundary(v.LV.mask,[r(minri) c(minri)],'N');
        middle = mean(v.LV.boundary);
        [theta,r] = cart2pol(v.LV.boundary(:,1) -middle(1), v.LV.boundary(:,2) -middle(2));
        r = r * 1.01;
        [x,y] = pol2cart(theta,r);
        x = x + middle(1); y = y + middle(2);
        v.LV.boundary = horzcat(x,y);
else
    %find a good place to center the initial circle
    imagesc(v.workingimage),colormap gray;
    set(handles.text1,'String','Please double click somewhere in the LV blood pool');
    colormap gray;
    v.waiting = 1;
    %xc = 104; yc = 54;
    while(v.waiting)
        pause(.3);
    end
    try
        set(handles.text1,'String','');
    catch
        disp('You closed the form.  I was so looking forward to this.');
        return;
    end
    
    
    %find when the LV/AIF has it's greatest rise and choose that frame for
    %segmentation
    LV = zeros(v.s3,1);
    for t=1:v.s3
        temp = v.data((v.xc(1)-2):(v.xc(1)+2),(v.yc(1)-2):(v.yc(1)+2),t);
        LV(t) = mean(temp(:));
    end
    dLV = diff(LV);
    [junk i] = max(dLV);
    bestFrame = v.data(:,:,i);

    clear x y;
    for i=1:20
        theta = i/20*2*pi;
        x(i) = v.xc(1) + 10*cos(theta);
        y(i) = v.yc(1) + 10*sin(theta);
    end
    v.LV.mask = roipoly(v.workingimage,x,y);
    %v.LV.alpha = .3;
    v.LV.alpha = 2;
    %[v.LV.mask v.LV.phi] = region_seg(v.workingimage, v.LV.mask, 500,v.LV.alpha ); %-- Run segmentation
    %[v.LV.mask v.LV.phi] = region_seg(bestFrame, v.LV.mask, 500,v.LV.alpha ); %-- Run segmentation
    v.LV.phi = [];
    v.LV.mask=bwfill(v.LV.mask,'holes');
    
    [r c] = find(v.LV.mask);
    v.center = mean([r c]);
    i = find(c == floor(v.center(2)));
    r = r(i);
    c = c(i);
    [minr minri] = min(r);
    v.LV.boundary = bwtraceboundary(v.LV.mask,[r(minri) c(minri)],'N');
end
plot(v.LV.boundary(:,2),v.LV.boundary(:,1),'b');

if(length(varargin)>3 || isfield(v,'epi'))
    if(length(varargin)>3)
        v.epi.boundary = varargin{4};
    end
    %reconstruct a mask
    v.epi.alpha = .1;
    v.epi.mask = roipoly(zeros(v.s1, v.s2)+1,v.epi.boundary(:,2),v.epi.boundary(:,1));
    v.epi.phi = [];
else
    %construct the epicardium based on the LV contour
    v.epi.alpha = 1.5;
    [theta r] = cart2pol(v.LV.boundary(:,1) - v.center(1), v.LV.boundary(:,2) - v.center(2));
    [maxr i] = max(r);
    
    prelimenaryEndoBoundary = floor([(r(i(1))*sin(0:.1:(2*pi)) + v.center(1));(r(i(1))*cos(0:.1:(2*pi)) + v.center(2))]');
    prelimenaryEndomask = roipoly(zeros(size(v.data(:,:,v.t)))+1,prelimenaryEndoBoundary(:,2), prelimenaryEndoBoundary(:,1));
    
    
    v.epi.mask=bwmorph(prelimenaryEndomask,'dilate',15);
    %v.epi.mask=bwmorph(v.epi.mask,'erode',7);
    %v.epi.mask=bwmorph(v.epi.mask,'dilate',18);
    v.epi.phi = [];
    %[v.epi.mask v.epi.phi]=region_seg(v.tedges, v.epi.mask, 500,v.epi.alpha); %-- Run segmentation
    %v.epi.mask=bwfill(v.epi.mask,'holes');
    
    %remove bridges
    %v.epi.mask=bwmorph(v.epi.mask,'erode',3);
    %v.epi.mask=bwmorph(v.epi.mask,'dilate',3);
    
    %remove all small islands
%     [s1 s2] = size(v.epi.mask);
%     [L, num] = bwlabel(v.epi.mask,8);
%     L = reshape(L,[s1 s2]);
%     areas = zeros(num,1);
%     for i=1:num
%         areas(i) = sum(sum(L == i));
%     end
%     [best winner] = max(areas);
%     [r c] = find(L == winner);
% 
%     v.epi.mask = zeros(s1,s2);
%     for i=1:length(r)
%         v.epi.mask(r(i),c(i)) = 1;
%     end
    
    [r c] = find(v.epi.mask);
    i = find(c == floor(v.center(2)));
    r = r(i);
    c = c(i);
    [minr minri] = min(r);
    v.epi.boundary = bwtraceboundary(v.epi.mask,[r(minri) c(minri)],'N');
        middle = mean(v.LV.boundary);
        [theta,r] = cart2pol(v.epi.boundary(:,1) -middle(1), v.epi.boundary(:,2) -middle(2));
        r = r * 1.01;
        [x,y] = pol2cart(theta,r);
        x = x + middle(1); y = y + middle(2);
        v.epi.boundary = horzcat(x,y);
end
plot(v.epi.boundary(:,2),v.epi.boundary(:,1),'b');

%endocardium
if(length(varargin)>4 || isfield(v,'endo'))
    if(length(varargin)>4)
        v.endo.boundary = varargin{5};
    end
    %reconstruct a mask
    v.endo.alpha = .1;
    v.endo.mask = roipoly(zeros(v.s1, v.s2)+1,v.endo.boundary(:,2),v.endo.boundary(:,1));
    v.endo.phi = [];
else
    [theta r] = cart2pol(v.LV.boundary(:,1) - v.center(1), v.LV.boundary(:,2) - v.center(2));
    [maxr i] = max(r);
    prelimenaryEndoBoundary = floor([(r(i(1))*sin(0:.1:(2*pi)) + v.center(1));(r(i(1))*cos(0:.1:(2*pi)) + v.center(2))]');
    v.endo.mask = roipoly(zeros(size(v.data(:,:,v.t)))+1,prelimenaryEndoBoundary(:,2), prelimenaryEndoBoundary(:,1));
    v.endo.mask=bwmorph(v.endo.mask,'dilate',3);
    
    v.endo.alpha = 2.5;
    [r c] = find(v.endo.mask);
    i = find(c == floor(v.center(2)));
    r = r(i);
    c = c(i);
    [minr minri] = min(r);
    v.endo.boundary = bwtraceboundary(v.endo.mask,[r(minri) c(minri)],'N');
        middle = mean(v.LV.boundary);
        [theta,r] = cart2pol(v.endo.boundary(:,1) -middle(1), v.endo.boundary(:,2) -middle(2));
        r = r * 1.01;
        [x,y] = pol2cart(theta,r);
        x = x + middle(1); y = y + middle(2);
        v.endo.boundary = horzcat(x,y);
end
plot(v.endo.boundary(:,2),v.endo.boundary(:,1),'b');
hold off
v.mutex = 0;
maskChanged(0);
v.mutex = 0;
showImage();
% --- Outputs from this function are returned to the command line.
function varargout = auto_segmentation_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
try
    varargout{1} = handles.output;
catch
    
end


% --- Executes on selection change in popupmenu1.
function popupmenu1_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = get(hObject,'String') returns popupmenu1 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu1
global v
contents = get(hObject,'String');
%disp(char(contents{get(hObject,'Value')}));
v.curtype = char(contents{get(hObject,'Value')});
if(strcmp(v.curtype,'Variance'))
    v.variance = std(v.data(:,:,:),0,3);
end
if(strcmp(v.curtype,'Variance'))
    v.workingimage = v.variance;
elseif(strcmp(v.curtype,'Frames'))
    v.workingimage = v.data(:,:,v.t);
else
    v.workingimage = 1-1./(1+(v.tedges/v.threshold).^v.power);
end
showImage();
uicontrol(handles.pushbutton5);

function showImage()
global v
if(~isfield(v,'mutex')) return; end;
if(v.mutex == 1 && v.waiting == 0) return; end
v.mutex = 1;
try
axes(v.handles.axes1);
if(strcmp(v.curtype,'Edges'))
    if(v.waiting)
        h = imagesc(v.tedges);
    else
        h = imagesc(v.workingimage);
    end
elseif(strcmp(v.curtype,'Frames'))
    if(v.overlays)
        if(strcmp(v.type,'epi'))
            mask =  v.epi.mask;
        elseif(strcmp(v.type,'endo'))
            mask = v.endo.mask;
        elseif(strcmp(v.type,'LV'))
            mask = v.LV.mask;
        end

        temp = zeros([size(v.tedges) 3]);
        mymax = max(max(v.data(:,:,v.t)));
        temp(:,:,3) = v.data(:,:,v.t)/mymax;
        temp(:,:,2) = v.data(:,:,v.t)/mymax;
        temp(:,:,1) = max(v.data(:,:,v.t)/mymax,mask)/2;
        h = imshow(temp);
        clear temp;
    else
        h = imagesc(v.data(:,:,v.t));
    end
elseif(strcmp(v.curtype,'Variance'))
    h = imagesc(v.variance);
end
set(v.handles.axes1, 'ButtonDownFcn', @axes1_ButtonDownFcn);
colormap gray
hold on
colors = 'rgycmb';
linetypes = '-.';
linetype = linetypes(v.DeletePressed+1);
dendo = size(v.endo.boundary,1)/6;
depi = size(v.epi.boundary,1)/6;
dLV = size(v.LV.boundary,1)/6;
[endoTheta endoR] = cart2pol(v.endo.boundary(:,2) - v.center(2),v.endo.boundary(:,1) - v.center(1));
[epiTheta epiR] = cart2pol(v.epi.boundary(:,2) - v.center(2),v.epi.boundary(:,1) - v.center(1));
[LVTheta LVR] = cart2pol(v.LV.boundary(:,2) - v.center(2),v.LV.boundary(:,1) - v.center(1));

for i=1:6
    thetamin = (i-1)/6*2*pi-pi;
    thetamax = i/6*2*pi-pi;
    
    qualifying_points = (endoTheta >= thetamin) & (endoTheta <= thetamax);
    thetas = endoTheta(qualifying_points);
    rs = endoR(qualifying_points);
    [thetas IX] = sort(thetas);
    rx = rs(IX);
    [x y] = pol2cart(thetas,rs);
    plot(x+ v.center(2),y+ v.center(1),[linetype(1) colors(i)],'LineWidth',(strcmp(v.type,'endo')+.5)*2);
    
    
    qualifying_points = (epiTheta >= thetamin) & (epiTheta <= thetamax);
    thetas = epiTheta(qualifying_points);
    rs = epiR(qualifying_points);
    [thetas IX] = sort(thetas);
    rx = rs(IX);
    [x y] = pol2cart(thetas,rs);
    plot(x+ v.center(2),y+ v.center(1),[linetype(2) colors(i)],'LineWidth',(strcmp(v.type,'epi')+.5)*2);
    
    
    qualifying_points = (LVTheta >= thetamin) & (LVTheta <= thetamax);
    thetas = LVTheta(qualifying_points);
    rs = LVR(qualifying_points);
    [thetas IX] = sort(thetas);
    rx = rs(IX);
    [x y] = pol2cart(thetas,rs);
    plot(x+ v.center(2),y+ v.center(1),[linetype(3) 'b'],'LineWidth',(strcmp(v.type,'LV')+.5)*2);

end
if(v.choosingStartAngle)
    point = [v.mousePoint(1) v.mousePoint(2)];
    dx = point(1) - v.center(1);
    dy = point(2) - v.center(2);  %compensate for a flipped vertical
    v.StartAngle = atan2(dy, dx);
end
[x y] = pol2cart([(v.StartAngle) (v.StartAngle)],[0 norm(v.endo.boundary(:,1))]);
line(y+v.center(2),x+v.center(1));


if(v.stamping)
    if(v.stampType)
        plusminus = '--';
        tcolors = 'r';
    else
        plusminus = '+';
        tcolors = 'b';
    end
    plot(.8*v.radius*sin(0:.3:(2*pi+.3)) + v.mousePoint(2),.8*v.radius*cos(0:.3:(2*pi+.3)) + v.mousePoint(1),tcolors);
    plot([v.mousePoint(2)-1 v.mousePoint(2)+1],[v.mousePoint(1) v.mousePoint(1)],plusminus);
end
hold off



top = max([max(v.bloodPool) max(v.curves(:))]);
axes(v.handles.axes2);
plot(v.bloodPool-mean(v.bloodPool(1:5)),'k');
hold on
for i=1:6
    plot(v.curves(i,:)-mean(v.curves(i,1:5)),colors(i));
end
plot([v.t v.t],[0 top],'k');
hold off
set(h,'HitTest', 'off');
catch ME
    x = 0;
end
v.mutex = 0;



% --- Executes during object creation, after setting all properties.
function popupmenu1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
v.type = 'epi';
showImage();

% --- Executes on button press in pushbutton2.
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
v.type = 'endo';
showImage();

% --- Executes on button press in pushbutton3.
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
v.type = 'LV';
showImage();

% --- Executes during object creation, after setting all properties.
function figure1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns calle


% --- Executes on mouse press over axes background.
function axes1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
if(~exist('v')) return; end;
if(isempty(v)) return; end;
%convert where they clicked to an index in our matrix
ratio = getPoint(v.handles.axes1);
ij = ceil(ratio.*size(v.endo.mask));
mouseside=get(v.handles.figure1,'SelectionType');
if(strcmp(mouseside,'alt'))
    v.RightClickDown = 1;
end
if(strcmp(mouseside,'normal'))
    v.LeftClickDown = 1;
end
showImage();


function ratio = getPoint(axesHandle)
global v
cp = get(v.handles.figure1,'CurrentPoint');cp = cp(1,1:2);
params = get(v.handles.axes1,'Position');
ratio = cp(1,1:2)./(params(3:4)); 
temp = ratio(1);
ratio(1) = ratio(2);
ratio(2) = temp;
ratio(1) = 1-ratio(1);

% --- Executes during object creation, after setting all properties.
function axes1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to axes1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: place code in OpeningFcn to populate axes1


% --- Executes on mouse motion over figure - except title and menu.
function figure1_WindowButtonMotionFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
if(~exist('v')) return; end;
if(isempty(v)) return; end;
if(v.mutex) return; end
ratio = getPoint(v.handles.axes1);
v.mousePoint =  ceil(ratio.*size(v.data(:,:,1)));
if(v.choosingStartAngle)
    showImage();
    return;
end

mouseside=get(v.handles.figure1,'SelectionType');
if(strcmp(mouseside,'alt') && ~v.control)
    v.mutex = 1;
    %move the mask
    if(strcmp(v.type,'endo'))
        currentSpot =  ceil(ratio.*size(v.endo.mask));
    elseif(strcmp(v.type,'epi'))
        currentSpot =  ceil(ratio.*size(v.epi.mask));
    else
        currentSpot =  ceil(ratio.*size(v.LV.mask));
    end
    if(isfield(v,'PreviousSpot') && v.RightClickDown)
        dpos = -(v.PreviousSpot - currentSpot);
        if(norm(dpos) > 5) v.mutex = 0; v.PreviousSpot = currentSpot;return; end;
        if(strcmp(v.type,'epi'))
            v.epi.mask = circshift( v.epi.mask,dpos);
        elseif(strcmp(v.type,'endo'))
            v.endo.mask = circshift( v.endo.mask,dpos);
        elseif(strcmp(v.type,'LV'))
            v.LV.mask = circshift( v.LV.mask,dpos);
        end
        maskChanged();
        
        v.PreviousSpot = currentSpot;
    else
        v.PreviousSpot = currentSpot;
    end
    v.mutex = 0;
    showImage();
end
if(strcmp(mouseside,'normal'))
    mutex = 1;
    %convert the selected boundary to polar and sort on angle
    if(v.LeftClickDown)
        if(v.stamping)
            if(strcmp(v.type,'epi'))
                mask = v.epi.mask;
            elseif(strcmp(v.type,'endo'))
                mask = v.endo.mask;
            elseif(strcmp(v.type,'LV'))
                mask = v.LV.mask;
            end
            
            point = [v.mousePoint(1) v.mousePoint(2)];
            h = fspecial('disk',v.radius);
            [s1 s2] = size(h);
            h = h>=(h(floor(s1/2),floor(s1/2))-.001);
            rangex = (point(1)-v.radius):(point(1)+v.radius);
            rangey = (point(2)-v.radius):(point(2)+v.radius);
            if (sum(rangex<1) + sum(rangex > size(mask,1)) > 0) || (sum(rangey<1) + sum(rangey > size(mask,2)) > 0)
                v.mutex = 0;
                return;
            end
            if(v.stampType)
                mask(rangex,rangey) = mask(rangex,rangey) - (mask(rangex,rangey) & h);
            else
                mask(rangex,rangey) = mask(rangex,rangey) | h;
            end
            if(strcmp(v.type,'epi'))
                v.epi.mask = mask;
            elseif(strcmp(v.type,'endo'))
                v.endo.mask = mask;
            elseif(strcmp(v.type,'LV'))
                v.LV.mask = mask;
            end
            maskChanged();
        end
        
        v.mutex = 0;
        showImage();
    end
    v.mutex = 0;
end

function updateCurves()
global v
v.myo = v.epi.mask - v.endo.mask;
[v.myoX v.myoY] = find(v.myo>0);
for i=1:length(v.myoX)
    angle = atan2(v.myoX(i)-v.center(1),v.myoY(i)-v.center(2));
    r = norm([v.myoX(i)-v.center(1) v.myoY(i)-v.center(2)]);
    %profileBins(round(),round()) = v.data(
    region = floor(((angle+pi)/(2*pi)) * 6)+1;
    v.myo(v.myoX(i),v.myoY(i)) = region;
end

%find profile



v.curves = zeros(6,v.s3);
%myocardium
for i=1:6
    mask = (v.myo == i);
    for t=1:v.s3
        temp = v.data(:,:,t);
        v.curves(i,t) = mean(temp( mask>0));
    end
end

%blood pool
v.bloodPool = zeros(1,v.s3);
for t=1:v.s3
    temp = v.data(:,:,t);
    v.bloodPool(t) = mean(temp( v.LV.mask>0));
    %temp = v.data(:,:,t) .* v.LV.mask;
    %v.bloodPool(t) = mean(temp(:));
end
        
% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over pushbutton1.
function pushbutton1_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

%grow the current region based on the current image
global v
if(strcmp(v.curtype,'Edges'))
    I = v.tedges;
elseif(strcmp(v.curtype,'Frames'))
    I = v.data(:,:,v.t);
elseif(strcmp(v.curtype,'Variance'))
    I = v.variance;
end
if(strcmp(v.type,'epi'))
    if(isempty(v.epi.phi))
        [v.epi.mask v.epi.phi] = region_seg(I,v.epi.mask,3,v.epi.alpha);
    else
        [v.epi.mask v.epi.phi] = region_seg(I,v.epi.mask,3,v.epi.alpha,v.epi.phi);
    end
elseif(strcmp(v.type,'endo'))
    if(isempty(v.endo.phi))
        [v.endo.mask v.endo.phi] = region_seg(I,v.endo.mask,3,v.endo.alpha);
    else
        [v.endo.mask v.endo.phi] = region_seg(I,v.endo.mask,3,v.endo.alpha,v.endo.phi);
    end
elseif(strcmp(v.type,'LV'))
    if(isempty(v.LV.phi))
        [v.LV.mask v.LV.phi] = region_seg(I,v.LV.mask,3,v.LV.alpha);
    else
        [v.LV.mask v.LV.phi] = region_seg(I,v.LV.mask,3,v.LV.alpha,v.LV.phi);
    end
end
maskChanged(0);
showImage();


% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over pushbutton2.
function pushbutton2_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)



% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over pushbutton3.
function pushbutton3_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on scroll wheel click while the figure is in focus.
function figure1_WindowScrollWheelFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	VerticalScrollCount: signed integer indicating direction and number of clicks
%	VerticalScrollAmount: number of lines scrolled for each click
% handles    structure with handles and user data (see GUIDATA)
global v
if(v.mutex) return; end;
v.mutex = 1;
MorphType = {'dilate','erode'};
MorphType = MorphType{(eventdata.VerticalScrollCount<0)+1};
radius = abs(eventdata.VerticalScrollCount);
if(v.stamping)
    v.radius = v.radius+abs(eventdata.VerticalScrollCount)*(2*(eventdata.VerticalScrollCount<0)-1);
else
    if(strcmp(v.type,'endo'))
        v.endo.mask = bwmorph(v.endo.mask,char(MorphType),radius);
    elseif(strcmp(v.type,'epi'))
        v.epi.mask = bwmorph(v.epi.mask,char(MorphType),radius);
    elseif(strcmp(v.type,'LV'))
        v.LV.mask = bwmorph(v.LV.mask,char(MorphType),radius);   
    else
        disp('What type were you thinking?');
    end
    maskChanged();
end
v.mutex = 0;
showImage();


% --- Executes on mouse press over figure background, over a disabled or
% --- inactive control, or over an axes background.
function figure1_WindowButtonUpFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
if(~exist('v')) return; end;
if(isempty(v)) return; end;
%convert where they clicked to an index in our matrix
ratio = getPoint(v.handles.axes1);
ij = ceil(ratio.*size(v.data(:,:,1)));
mouseside=get(v.handles.figure1,'SelectionType');
if(strcmp(mouseside,'alt'))
    v.RightClickDown = 0;
end
if(strcmp(mouseside,'normal'))
    v.LeftClickDown = 0;
end
showImage();


% --- Executes on key press with focus on figure1 or any of its controls.
function figure1_WindowKeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)
global v
if(~isfield(eventdata,'Key'))
    return;
end
keyinput = eventdata.Key;shift = [0 0];
v.control = strcmp(keyinput,'control');
v.alt = strcmp(keyinput,'alt');
v.shift = strcmp(keyinput,'shift');
if(strcmp(keyinput,'s') && v.control)
    %save current contours
    cd('Output');
    tmpname=['endo_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
    temp = v.endo.boundary;
    save(tmpname, 'temp','-ascii');
    tmpname=['epi_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
    temp = v.epi.boundary;
    save(tmpname, 'temp','-ascii');
    tmpname=['blood_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
    temp = v.LV.boundary;
    save(tmpname, 'temp','-ascii');
    cd('..');
elseif(strcmp(keyinput,'s') && v.alt)
    if(v.stamping)
        v.stamping = 0;
        set(v.handles.pushbutton6,'FontWeight','normal');
    else
        v.stamping = 1;
        set(v.handles.pushbutton6,'FontWeight','bold');
    end
elseif strcmp(keyinput,'h') || strcmp(keyinput,'w') || strcmp(keyinput,'uparrow')
    shift = [-1 0];
elseif strcmp(keyinput,'j') || strcmp(keyinput,'d') || strcmp(keyinput,'rightarrow')
    shift = [0 1];
elseif strcmp(keyinput,'k') || strcmp(keyinput,'a') || strcmp(keyinput,'leftarrow')
    shift = [0 -1];
elseif strcmp(keyinput,'l') || strcmp(keyinput,'s') || strcmp(keyinput,'downarrow')
    shift = [1 0];
end
if(sum(abs(shift)) > 0)
    if(strcmp(eventdata.Modifier,'shift'))
        if(strcmp(v.type,'endo'))
            v.endo.mask = circshift(v.endo.mask,shift);
        elseif(strcmp(v.type,'epi'))
            v.epi.mask = circshift(v.epi.mask,shift);
        elseif(strcmp(v.type,'LV'))
            v.epi.mask = circshift(v.epi.mask,shift);
        else
            disp('What type were you thinking?');
        end
        maskChanged();
    else
        v.shifts(v.t,:) = v.shifts(v.t,:) + shift;
        v.data(:,:,v.t) = circshift(v.data(:,:,v.t),shift);
    end
    updateCurves();
end
if strcmp(keyinput,'space') ||  strcmp(keyinput,'return') ||  strcmp(keyinput,'pagedown')
    v.t = v.t+1;
    if(v.t == v.s3+1)
        v.t = 1;
    end
end
if(strcmp(keyinput,'add') || strcmp(keyinput,'subtract'))
    axes(v.handles.axes1);
    v.threshold = v.threshold+strcmp(keyinput,'add')*2 -1;
    v.workingimage = 1-1./(1+(v.tedges/v.threshold).^v.power);
    imagesc(v.workingimage);
    set(v.handles.axes1, 'ButtonDownFcn', @axes1_ButtonDownFcn);
end
if(strcmp(keyinput,'multiply') || strcmp(keyinput,'divide'))
    axes(v.handles.axes1);
    v.power = v.power*(1+.1*(strcmp(keyinput,'multiply')*2 -1));
    v.workingimage = 1-1./(1+(v.tedges/v.threshold).^v.power);
    imagesc(v.workingimage);
    set(v.handles.axes1, 'ButtonDownFcn', @axes1_ButtonDownFcn);
end

if strcmp(keyinput,'backspace') ||  strcmp(keyinput,'pageup')
    v.t = v.t-1;
    if(v.t == 0)
        v.t = v.s3;
    end
end
if strcmp(keyinput,'delete')
    axes(v.handles.axes1);
    v.mutex = 1;
    if(strcmp(v.type,'endo'))
        v.DeletePressed = [1 0 0];
    elseif(strcmp(v.type,'epi'))
        v.DeletePressed = [0 1 0];
    elseif(strcmp(v.type,'LV'))
        v.DeletePressed = [0 0 1];
    end
    v.mutex = 0;
    showImage();
    v.DeletePressed = [0 0 0];
    axes(handles.axes1);
    v.mutex = 1;
    [mask x y] = roipoly;
    if(strcmp(v.type,'endo'))
        v.endo.mask = mask;
    elseif(strcmp(v.type,'epi'))
        v.epi.mask = mask;
    elseif(strcmp(v.type,'LV'))
        v.LV.mask = mask;
    end
    maskChanged();
    v.mutex = 0;
end
if strcmp(keyinput,'tab')
    if(v.stamping)
        v.stampType = ~v.stampType;
        type = {'out','in'};
        set(v.handles.pushbutton6,'String',['Bump ' char(type(v.stampType+1))]);
    else
        if(strcmp(v.type,'LV'))
            v.type = 'epi';
        elseif(strcmp(v.type,'epi'))
            v.type = 'endo';
        else
            v.type = 'LV';
        end
    end
end
if strcmp(keyinput,'escape')
    if(v.stamping)
        v.stamping = 0;
        set(v.handles.pushbutton6,'FontWeight','normal');
        set(v.handles.pushbutton6,'String','Bump');
    else
        figure1_CloseRequestFcn(hObject, eventdata, handles)
    end
end
showImage();


% --- Executes on key release with focus on figure1 and none of its controls.
function figure1_KeyReleaseFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was released, in lower case
%	Character: character interpretation of the key(s) that was released
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) released
% handles    structure with handles and user data (see GUIDATA)
global v
keyinput = eventdata.Key;
v.control = ~strcmp(keyinput,'control');
v.alt = ~strcmp(keyinput,'alt');
v.shift = ~strcmp(keyinput,'shift');
showImage();


function maskChanged(emptyPhi)
 global v
 if(strcmp(v.type,'endo'))
    [r c] = find(v.endo.mask);
    i = find(c == floor(mean(c)));
    r = r(i);
    c = c(i);
    [minr minri] = min(r);
    try
        v.endo.boundary = bwtraceboundary(v.endo.mask,[r(minri) c(minri)],'N');
        middle = mean(v.endo.boundary);
        [theta,r] = cart2pol(v.endo.boundary(:,1) -middle(1), v.endo.boundary(:,2) -middle(2));
        r = r * 1.01;
        [x,y] = pol2cart(theta,r);
        x = x + middle(1); y = y + middle(2);
        v.endo.boundary = horzcat(x,y);
    catch ME
        x = 0;
    end
    if(exist('emptyPhi') && emptyPhi)    v.endo.phi = [];  end
elseif(strcmp(v.type,'epi'))
    [r c] = find(v.epi.mask);
    i = find(c == floor(mean(c)));
    r = r(i);
    c = c(i);
    [minr minri] = min(r);
    try
        v.epi.boundary = bwtraceboundary(v.epi.mask,[r(minri) c(minri)],'N');
        middle = mean(v.epi.boundary);
        [theta,r] = cart2pol(v.epi.boundary(:,1) -middle(1), v.epi.boundary(:,2) -middle(2));
        r = r * 1.01;
        [x,y] = pol2cart(theta,r);
        x = x + middle(1); y = y + middle(2);
        v.epi.boundary = horzcat(x,y);
    catch ME
        x = 0;
    end
    if(exist('emptyPhi') && emptyPhi)    v.epi.phi = [];  end
 elseif(strcmp(v.type,'LV'))
    [r c] = find(v.LV.mask);
    v.center = mean([r c]);
    i = find(c == floor(mean(c)));
    r = r(i);
    c = c(i);
    [minr minri] = min(r);
    try
        v.LV.boundary = bwtraceboundary(v.LV.mask,[r(minri) c(minri)],'N');
        middle = mean(v.LV.boundary);
        [theta,r] = cart2pol(v.LV.boundary(:,1) -middle(1), v.LV.boundary(:,2) -middle(2));
        r = r * 1.01;
        [x,y] = pol2cart(theta,r);
        x = x + middle(1); y = y + middle(2);
        v.LV.boundary = horzcat(x,y);
    catch ME
        x = 0;
    end
    if(exist('emptyPhi') && emptyPhi)    v.LV.phi = [];  end
 else
    disp('What type were you thinking?');
 end

%find index of boundary_xy point that crosses the -pi to pi line and shift
%the boundary so that that point is first
[Theta R] = cart2pol(v.endo.boundary(:,2) - v.center(2),v.endo.boundary(:,1) - v.center(1));
[mintheta i] = min(Theta);
v.endo.boundary = circshift(v.endo.boundary,[-(i-1) 0]);

[Theta R] = cart2pol(v.epi.boundary(:,2) - v.center(2),v.epi.boundary(:,1) - v.center(1));
[mintheta i] = min(Theta);
v.epi.boundary = circshift(v.epi.boundary,[-(i-1) 0]);

[Theta R] = cart2pol(v.LV.boundary(:,2) - v.center(2),v.LV.boundary(:,1) - v.center(1));
[mintheta i] = min(Theta);
v.LV.boundary = circshift(v.LV.boundary,[-(i-1) 0]);
updateCurves();

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
global v
try
    choice = questdlg('Do you wish to save the contours you made?:','Yes','No');
    switch choice
        case 'Yes'
        disp('Saving contours created');
        if(isempty(v.series))
            disp('Please pick either an endo/epi/blood poly coords file and I''ll do the rest');
            [filename,Pathname,FilterIndex] = uigetfile('*','Select a contour-file');
            if(isempty(filename)) 
                %they didn't give us a filename so we don't know how to save
                %the contours given
                disp('Endo contour');
                disp(v.endo.boundary);
                disp('Epi contour');
                disp(v.epi.boundary);
                disp('blood contour');
                disp(v.LV.boundary);
                disp('Good bye');
                delete(hObject);
                return;
            end
            i1 = findstr(filename,'.study');
            i2 = findstr(filename,'.slice');
            v.series = str2num(filename((i1+6):(i2-1)));
            v.slice = str2num(filename((i2+6):end));
        end
        cd('Output');
        tmpname=['endo_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
        temp = v.endo.boundary(:,[2 1]);
        save(tmpname, 'temp','-ascii');
        tmpname=['epi_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
        temp = v.epi.boundary(:,[2 1]);
        save(tmpname, 'temp','-ascii');
        tmpname=['blood_polyCoords.study' int2str(v.series) '.slice' int2str(v.slice)];
        temp = v.LV.boundary(:,[2 1]);
        save(tmpname, 'temp','-ascii');
        start_angle = v.StartAngle;
        tmpname = strcat('Roi_start_angle.study',int2str(v.series),'.slice',int2str(v.slice));
        save(tmpname,'start_angle','-ascii');
        cd('..');
    end
    %saving any shifts made
    if(sum(sum(abs(v.shifts))) > 0)
        choice = questdlg('Do you wish to save the shifts you made?:','Yes','No');
        switch choice
            case 'Yes'
                

                %% open up the cinemri file, record what was in there, overwrite the
                %  variable that held the movie then save it back
                matcontents = whos('-file',v.filename);
                savedVariables = matcontents(1).name;
                if(length(matcontents)>1)
                    for i=2:length(matcontents)
                        savedVariables = [savedVariables '|' matcontents(i).name];
                    end
                end

                %v.data has already been shifted so we need to update the matfile
                load(v.filename);
                if(exist('imgrr'))
                    imgrr = v.data;
                elseif(exist('cinemri'))
                    cinemri = v.data;
                elseif(exist('cinemri1'))
                    cinemri1 = v.data;
                else
                    disp(['I could not figure out what variable was contained in' v.filename]);
                end
                try
                    save(v.filename,'-regexp',savedVariables);
                catch
                    disp(['I could not update the cinemri file: ' v.filename]);
                end
                cd('Output');
                    if(isempty(v.series))
                        disp('Couldn''t find the MANshift file. Please find it so I can save the shifts you made');
                        [MANshiftfilename,PathName,FilterIndex] = uigetfile('*.txt','Select the shift-file');
                        if(isempty(MANshiftfilename)) disp('I think you canceled');return; end
                    else
                        MANshiftfilename=strcat('shiftsMAN.study',int2str(v.series),'.slice',int2str(v.slice),'.txt');
                    end
                    if(exist(MANshiftfilename))
                        temp = load(MANshiftfilename);
                        v.shifts(:,:) = v.shifts(:,:) + temp;  %modify the current shifts already there
                    else
                        disp(['No manual shift file found.  Creating ' MANshiftfilename]);
                    end
                    %create a MANshifts file
                    fid = fopen(MANshiftfilename,'w');
                    for t=1:v.s3
                        fprintf(fid,'%f %f\n',v.shifts(t,1),v.shifts(t,2));
                    end
                    fclose(fid); 
                cd('..');
                    cinemri1 = v.data;
                    save(v.filename,'cinemri1');
                
            case 'No'
                disp(v.shifts);
        end
    end
catch
    
end
temp = pwd;
if(strcmp(temp((end-5):end),'Output'))
    cd('..');
end
close(figure(2));
clear global v
delete(hObject);


% --- Executes on mouse press over figure background, over a disabled or
% --- inactive control, or over an axes background.
function figure1_WindowButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
if(~exist('v')) return; end;
if(isempty(v)) return; end;
%convert where they clicked to an index in our matrix
ratio = getPoint(v.handles.axes1);
mouseside=get(v.handles.figure1,'SelectionType');
if(strcmp(mouseside,'alt'))
    v.RightClickDown = 1;
end
if(strcmp(mouseside,'normal'))
    v.LeftClickDown = 1;
    if(v.waiting)
        v.mousePoint =  ceil(ratio.*size(v.data(:,:,1)));
        v.yc = v.mousePoint(1);
        v.xc = v.mousePoint(2);
        if(v.yc > 0 && v.xc > 0 && v.yc < size(v.data(:,:,1),1) && v.xc < size(v.data(:,:,1),2) )
            v.waiting = 0;
        end
    end
    if(v.choosingStartAngle)
        v.choosingStartAngle = 0;
        v.mousePoint =  ceil(ratio.*size(v.endo.mask));
        point = [v.mousePoint(1) v.mousePoint(2)];
        dx = point(1) - v.center(1);
        dy = point(2) - v.center(2);
        v.StartAngle = atan2(dy, dx);  % copied from mpi_pickStartAngle
        if(isempty(v.series))
            disp('No series number could be extracted from the given filename.  No starting angle file saved.');
            return;
        end
        cd('Output');
            tmpname = strcat('Roi_start_angle.study',int2str(v.series),'.slice',int2str(v.slice));
            start_angle = v.StartAngle;
            save(tmpname, 'start_angle','-ascii');
        cd('..');
    end
end

% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
if(v.stamping)
    set(hObject,'FontWeight','normal');
    v.stamping = 0;
    set(v.handles.pushbutton6,'String','Bump');
else
    set(hObject,'FontWeight','Bold');
    v.stamping = 1;
    type = {'out','in'};
    set(v.handles.pushbutton6,'String',['Bump ' char(type(v.stampType+1))]);
end
showImage();

% --- If Enable == 'on', executes on mouse press in 5 pixel border.
% --- Otherwise, executes on mouse press in 5 pixel border or over pushbutton6.
function pushbutton6_ButtonDownFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
if(v.stamping)
    set(hObject,'FontWeight','normal');
    v.stamping = 0;
    set(v.handles.pushbutton6,'String','Bump');
else
    set(hObject,'FontWeight','Bold');
    v.stamping = 1;
    type = {'out','in'};
    set(v.handles.pushbutton6,'String',['Bump ' char(type(v.stampType+1))]);
end
showImage();

% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
v.choosingStartAngle = 1;
updateCurves();
showImage();


% --- Executes when figure1 is resized.
function figure1_ResizeFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in pushbutton8.
function pushbutton8_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global v
if(v.overlays)
    set(hObject,'FontWeight','normal');
    v.overlays = 0;
    set(v.handles.pushbutton8,'String','Overlays off');
else
    set(hObject,'FontWeight','Bold');
    v.overlays = 1;
    type = {'out','in'};
    set(v.handles.pushbutton8,'String','Overlays On ');
end
showImage();


% --- Executes on key press with focus on figure1 and none of its controls.
function figure1_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  structure with the following fields (see FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)
