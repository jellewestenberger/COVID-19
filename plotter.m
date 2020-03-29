clear all 
reports=dir("csse_covid_19_data\csse_covid_19_daily_reports\*.csv");
country="Netherlands";
timestampsfiles=[];
for j=1:size(reports,1)
    timestamp=split(reports(1).name,'.csv');
    timestamp=datetime(timestamp{1},'InputFormat','MM-dd-yyy');
    timestampsfiles=[timestampsfiles;j,posixtime(timestamp)];
end
if isfile('Database.mat')
    load('Database.mat');
    if isfield(database,country)
    LastUpdate=posixtime(database.(country).LastUpdate);
    else
        database.(country).LastUpdate=[];
        LastUpdate=0;
    end
else
   database.(country).LastUpdate=[];
   LastUpdate=0;
end
%%

newfiles=find(timestampsfiles(:,2)>LastUpdate);
reports=reports(newfiles);
timestampfiles=timestampsfiles(newfiles);
%%



for j=1:size(reports,1)
    filename=reports(j).name;
    filepath=strcat(reports(j).folder,"\",filename);
    alldata=readtable(filepath);
    i=find(ismember(alldata.Country_Region,country));
    if not(length(i)==0)   
        dat=alldata(i,:);
        if length(i)>1
            dummy=2;
        end
        varnames=dat.Properties.VariableNames;
        for L=1:length(varnames)
            if regexp(varnames{L},regexptranslate('wildcard',"*Province_State*"))
                dat.Properties.VariableNames(1,L)={'Province_State'};
            end
            if regexp(varnames{L},regexptranslate('wildcard',"*Last*Update*"))
                dat.Properties.VariableNames(1,L)={'LastUpdate'};
            end
        end
        for q=1:size(dat,1)
    %         q=find(ismember(dat.Province_State,"")); % find empty province (ignore Sint-maarten etc)
    %         if length(q)==0
    %             q=find(ismember(dat.Province_State,country));
    %         end


            datprov=dat(q,:);  
            if isa(datprov.LastUpdate,'datetime')
                time=datprov.LastUpdate;
                time.Year=2020;
            elseif isa(datprov.LastUpdate{1},'string')||isa(datprov.LastUpdate{1},'char')
                time=split(datprov.LastUpdate,"T");
                time=strcat(time{1}," ",time{2});     
                time=datetime(time,'InputFormat','yyyy-MM-dd HH:mm:ss');
            else
                dummy=2;
            end
            province=replace(datprov.Province_State{1}," ","");
            if strcmp(province,'')
                province=country;
            end
            nrcases=datprov.Confirmed;
            nrdeath=datprov.Deaths;
            nrrecovered=datprov.Recovered;
            if isfield(database.(country),province)
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
fields=fieldnames(database.(country));
timel=[];
for i =1:size(fields,1)
   if isa(database.(country).(fields{i}),'struct')
       timel=[timel;posixtime(database.(country).(fields{i}).lastupdate)];
   end
end
database.(country).LastUpdate=datetime(max(timel),'ConvertFrom','epochtime');

save("Database.mat",'database');
% 
% figure()
% plot(database.(country).timestamps,database.(country).confirmed)
% hold on 
% plot(database.(country).timestamps,database.(country).deaths,'r')
% hold on 
% plot(database.(country).timestamps,database.(country).recovered,'g')
% title(country);
% grid on
% legend("Confirmed Cases","Deaths","Recovered")