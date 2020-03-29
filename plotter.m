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
    LastUpdate=posixtime(database.(country).lastupdate);
    else
        LastUpdate=0;
        database.(country).confirmed=[];
        database.(country).deaths=[];
        database.(country).recovered=[];
        database.(country).timestamps=[];
    end
else
   LastUpdate=0;
   database.(country).confirmed=[];
    database.(country).deaths=[];
    database.(country).recovered=[];
    database.(country).timestamps=[];
end
%%

newfiles=find(timestampsfiles(:,2)>LastUpdate);
reports=reports(newfiles);
%%

timel=[];
nrcases=[];
nrdeath=[];
nrrecovered=[];

for j=1:size(reports,1)
    filename=reports(j).name;
    filepath=strcat(reports(j).folder,"\",filename);
    alldata=readtable(filepath);
    i=find(ismember(alldata.Country_Region,country));
    if not(length(i)==0)   
        dat=alldata(i,:);
        
        varnames=dat.Properties.VariableNames;
        for L=1:length(varnames)
            if regexp(varnames{L},regexptranslate('wildcard',"*Province_State*"))
                dat.Properties.VariableNames(1,L)={'Province_State'};
            end
            if regexp(varnames{L},regexptranslate('wildcard',"*Last*Update*"))
                dat.Properties.VariableNames(1,L)={'LastUpdate'};
            end
        end
        q=find(ismember(dat.Province_State,"")); % find empty province (ignore Sint-maarten etc)
        if length(q)==0
            q=find(ismember(dat.Province_State,country));
        end
           
        
        dat=dat(q,:);  
        if isa(dat.LastUpdate,'datetime')
            time=dat.LastUpdate;
           	time.Year=2020;
        elseif isa(dat.LastUpdate{1},'string')||isa(dat.LastUpdate{1},'char')
            time=split(dat.LastUpdate,"T");
            time=strcat(time{1}," ",time{2});     
            time=datetime(time,'InputFormat','yyyy-MM-dd HH:mm:ss');
        else
            dummy=2;
        end
        
   
        nrcases=[nrcases;dat.Confirmed];
        nrdeath=[nrdeath;dat.Deaths];
        nrrecovered=[nrrecovered;dat.Recovered];
        timel=[timel;posixtime(time)];
    end
end

%%
[timel,I]=sort(timel);
database.(country).confirmed=[database.(country).confirmed;nrcases(I)];
database.(country).deaths=[database.(country).deaths;nrdeath(I)];
database.(country).recovered=[database.(country).recovered;nrrecovered(I)];
database.(country).timestamps=[database.(country).timestamps; timel];
if length(timel)>0
    database.(country).lastupdate=datetime(timel(end),'ConvertFrom','epochtime');
end
save("Database.mat",'database');
figure()
plot(database.(country).timestamps,database.(country).confirmed)
hold on 
plot(database.(country).timestamps,database.(country).deaths,'r')
hold on 
plot(database.(country).timestamps,database.(country).recovered,'g')
title(country);
grid on
legend("Confirmed Cases","Deaths","Recovered")