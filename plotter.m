clear all

country="Netherlands";
%% Check whether country has been loaded in database before and if there is new data available

if isfile('Database.mat')
    load('Database.mat');
    if isfield(database,country)
    LastUpdate=posixtime(database.(country).LastUpdate); %timestamp of latest database entry
    else
        database.(country).LastUpdate=[];
        LastUpdate=0;
    end
else
   database.(country).LastUpdate=[];
   database.LastRemoteUpdate=datetime(0,'ConvertFrom','epochtime');
   LastUpdate=0;
end

%% make sure to have https://github.com/CSSEGISandData/COVID-19.git as a remote called origin (or modify remote name at fetch below) 
curtime=datetime(now,'ConvertFrom','datenum');
lastupdatetime=posixtime(database.LastRemoteUpdate);
if (posixtime(curtime)-lastupdatetime)>3600 %only update when more than an hour has passed since the last update
    disp("Checking for updates");
    !git fetch origin
    !git checkout origin/master csse_covid_19_data\ 
    database.LastRemoteUpdate=curtime;
end
reports=dir("csse_covid_19_data\csse_covid_19_daily_reports\*.csv");


timestampsfiles=[];
for j=1:size(reports,1)
    timestamp=split(reports(j).name,'.csv');
    timestamp=datetime(timestamp{1},'InputFormat','MM-dd-yyyy');
    timestampsfiles=[timestampsfiles;j,posixtime(timestamp)]; % time stamps of reports csv
end
%%


newfiles=find(timestampsfiles(:,2)>LastUpdate); %filter new reports only
reports=reports(newfiles);
timestampfiles=timestampsfiles(newfiles);
%%



for j=1:size(reports,1)
    filename=reports(j).name;
    fprintf("New data: %s\n",filename);
    filepath=strcat(reports(j).folder,"\",filename);
    alldata=readtable(filepath);
    i=find(ismember(alldata.Country_Region,country)); %find entries that correspond with desired country
    if not(length(i)==0)   
        dat=alldata(i,:);
        if length(i)>1
            dummy=2;
        end
        varnames=dat.Properties.VariableNames;
        for L=1:length(varnames)
            if regexp(varnames{L},regexptranslate('wildcard',"*Province_State*")) % fix mislabeled column names
                dat.Properties.VariableNames(1,L)={'Province_State'};
            end
            if regexp(varnames{L},regexptranslate('wildcard',"*Last*Update*"))
                dat.Properties.VariableNames(1,L)={'LastUpdate'};
            end
        end
        for q=1:size(dat,1) %loop over provinces
            datprov=dat(q,:);  
            if isa(datprov.LastUpdate,'datetime') % sometimes date entries are interpreted as strings and sometimes as datetime
                time=datprov.LastUpdate;
                time.Year=2020; %some year entries (i.e. 0020) are interpreted wrong
            elseif isa(datprov.LastUpdate{1},'string')||isa(datprov.LastUpdate{1},'char')
                time=split(datprov.LastUpdate,"T");
                time=strcat(time{1}," ",time{2});     
                time=datetime(time,'InputFormat','yyyy-MM-dd HH:mm:ss');
            else
                dummy=2; %for debugging brakepoint only
            end
            province=replace(datprov.Province_State{1}," ",""); %remove white spaces as they cannot be used as fieldnames
            province=replace(province,",","_");
            province=replace(province,".","");
            province=split(province,"(");
            province=province{1};
            if strcmp(province,'') % if not province name is given use the country name
                province=country;
            end
            nrcases=datprov.Confirmed;
            nrdeath=datprov.Deaths;
            nrrecovered=datprov.Recovered;
            if isfield(database.(country),province) % check if province exists in database
                database.(country).(province).confirmed=[database.(country).(province).confirmed;nrcases];
                database.(country).(province).deaths=[database.(country).(province).deaths;nrdeath];
                database.(country).(province).recovered=[database.(country).(province).recovered;nrrecovered];
                database.(country).(province).timestamps=[database.(country).(province).timestamps; posixtime(time)];
                if time>database.(country).(province).lastupdate
                    database.(country).(province).lastupdate=time;
                end
            else
               
                database.(country).(province).confirmed=[nrcases];                
                database.(country).(province).deaths=[nrdeath];
                database.(country).(province).recovered=[nrrecovered];
                database.(country).(province).timestamps=[posixtime(time)];
                database.(country).(province).lastupdate=time;
            end
            % sort by time
            [~,I]=sort(database.(country).(province).timestamps);
            database.(country).(province).confirmed=database.(country).(province).confirmed(I);
            database.(country).(province).deaths=database.(country).(province).deaths(I);
            database.(country).(province).recovered=database.(country).(province).recovered(I);
            database.(country).(province).timestamps=database.(country).(province).timestamps(I);
%             timel=timel;
        end
    end
end

%% 
% update global lastupdate for country
fields=fieldnames(database.(country));
timel=[];
for i =1:size(fields,1)
   if isa(database.(country).(fields{i}),'struct')
       timel=[timel;posixtime(database.(country).(fields{i}).lastupdate)];
   end
end
database.(country).LastUpdate=datetime(max(timel),'ConvertFrom','epochtime');

save("Database.mat",'database');

tl=database.(country).(country).timestamps;
tl=tl-tl(1);
tl=tl./(3600*24);
meas=1:length(tl); %measurment range on which lsq is based
tl_meas=tl(meas);
y=database.(country).(country).confirmed(meas);
tl_extra=tl_meas(end):1:tl(end)+5;
order=4;
A=zeros(length(y),order+1);
% A(:,1)=ones(length(y),1);
for i=0:order
   A(:,i+1)=tl_meas.^(i);
end
est=(A'*A)^(-1)*A'*y;
y_curve=A*est;
B=[];
y_extra=0;
for n=0:order
y_extra=y_extra+est(n+1).*tl_extra.^(n);
end

close all
figure()
plot(tl,database.(country).(country).confirmed)
hold on 
plot(tl_meas,y_curve);
hold on 
plot(tl_extra,y_extra,'--');
hold on
plot(tl,database.(country).(country).deaths,'r')
hold on 
plot(tl,database.(country).(country).recovered,'g')
title(country);
grid on
legend("Confirmed Cases","Fitted curve","extrapolated","Deaths","Recovered")