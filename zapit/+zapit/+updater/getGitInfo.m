function gitInfo = getGitInfo
% Get information about the Git repository in the current directory.
%
% function gitInfo = zapit.updater.getGitInfo()
%
% Purpose
% Get information about the Git repository in the current directory. Including:
%          - branch name of the current Git Repo 
%          -Git SHA1 HASH of the most recent commit
%          -url of corresponding remote repository, if one exists
%
% The function first checks to see if a .git/ directory is present. If so it
% reads the .git/HEAD file to identify the branch name and then it looks up
% the corresponding commit.
%
% It then reads the .git/config file to find out the url of the
% corresponding remote repository. This is all stored in a gitInfo struct.
%
% Note this uses only file information, it makes no external program 
% calls at all. 
%
% This function must be in the base directory of the git repository
%
% Released under a BSD open source license. Based on a concept by Marc
% Gershow.
%
% Andrew Leifer
% Harvard University
% Program in Biophysics, Center for Brain Science, 
% and Department of Physics
% leifer@fas.harvard.edu
% http://www.andrewleifer.com
% 12 September 2011
%
%
%
% Modifed 2020 by Rob Campbell, UCL, to make it more robust and allow it to be inserted into any project
%
% Instructions: place into your project path e.g. put into `myProj/code/+utils/getGitInfo.m`
% then just call it at the command line: >> utils.getGitInfo


% Copyright 2011 Andrew Leifer. All rights reserved.
%
% Redistribution and use in source and binary forms, with or without modification, are
% permitted provided that the following conditions are met:
%
%    1. Redistributions of source code must retain the above copyright notice, this list of
%       conditions and the following disclaimer.
% 
%    2. Redistributions in binary form must reproduce the above copyright notice, this list
%       of conditions and the following disclaimer in the documentation and/or other materials
%       provided with the distribution.
% 
% THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ''AS IS'' AND ANY EXPRESS OR IMPLIED
% WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
% FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
% ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
% ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
% 
% The views and conclusions contained in the software and documentation are those of the
% authors and should not be interpreted as representing official policies, either expressed
% or implied, of the copyright holder.




% Make an empty structure so we return something
gitInfo.branch='UNKNOWN';
gitInfo.hash='UNKNOWN';
gitInfo.remote='UNKNOWN';
gitInfo.url='UNKNOWN';


% Descend dir path until we find the the .git directory
pathToFile=mfilename('fullpath');
while length(pathToFile)>1
    pathToFile = fileparts(pathToFile);
    pathToDotGit = fullfile(pathToFile,'.git');
    if exist(pathToDotGit,'dir')
        break
    end
end

verbose = false;

% In case nothing was found
if length(pathToFile)==1
    if verbose
        fprintf('%s failed to find a .git directory in project.\n', mfilename);
    end
    return
end

%Read in the HEAD information, this will tell us the location of the file
%containing the SHA1
headFile = fullfile(pathToDotGit,'HEAD');
if ~exist(headFile,'file')
    fprintf('%s failed to find file %s.\n', mfilename,headFile);
    return
end
text=fileread(headFile);
parsed=textscan(text,'%s');


if ~strcmp(parsed{1}{1},'ref:') || ~length(parsed{1})>1
    %If the HEAD is not in the expected format we give up
    fprintf('%s failed to parse HEAD.\n', mfilename);
    return
end

path=parsed{1}{2};
[pathstr, name, ext]=fileparts(path);
branchName=name;

%save branch name
gitInfo.branch=branchName;


%Read in SHA1 if the file is present (sometimes it's missing because Git has removed it)
SHA1_text_file=fullfile(pathToDotGit, pathstr,[name ext]);
SHA1=[];
if exist(SHA1_text_file)
    SHA1text=fileread(SHA1_text_file);
    SHA1=textscan(SHA1text,'%s');
else
    % Otherwise let's see if packed refs exist
    packedRefs = fullfile(pathToDotGit,'packed-refs');

    if exist(packedRefs,'file')
        SHA1text=fileread(packedRefs);
        SHA1=regexp(SHA1text,['([A-z0-9]*) refs/heads/' branchName],'tokens');
    else
        fprintf('%s failed to find packed refs\n',mfilename)
    end
end

if ~isempty(SHA1)
    gitInfo.hash=SHA1{1}{1};
else
   fprintf('%s failed to get SHA1 hash\n',mfilename)
end


%Read in config file
configFile = fullfile(pathToDotGit,'config');
if ~exist(configFile,'file')
    fprintf('%s failed to find file %s.\n', mfilename,configFile);
    return
end

config=fileread(configFile);
%Find everything space delimited
temp=textscan(config,'%s','delimiter','\n');
lines=temp{1};

remote='';
%Lets find the name of the remote corresponding to our branchName
for k=1:length(lines)

    %Are we at the section describing our branch?
    if strcmp(lines{k},['[branch "' branchName '"]'])
        m=k+1;
        %While we haven't run out of lines
        %And while we haven't run into another section (which starts with
        % an open bracket)
        while (m<=length(lines) && ~strcmp(lines{m}(1),'[') )
            temp=textscan(lines{m},'%s');
            if length(temp{1})>=3
                if strcmp(temp{1}{1},'remote') && strcmp(temp{1}{2},'=')
                    %This is the line that tells us the name of the remote 
                    remote=temp{1}{3};
                end
            end
            
            m=m+1;
        end
    end

end
gitInfo.remote=remote;


url='';
%Find the remote's url
for k=1:length(lines)

    %Are we at the section describing our branch?
    if strcmp(lines{k},['[remote "' remote '"]'])
        m=k+1;
        %While we haven't run out of lines
        %And while we haven't run into another section (which starts with
        % an open bracket)
        while (m<=length(lines) && ~strcmp(lines{m}(1),'[') )
            temp=textscan(lines{m},'%s');
            if length(temp{1})>=3
                if strcmp(temp{1}{1},'url') && strcmp(temp{1}{2},'=')
                    %This is the line that tells us the name of the remote 
                    url=temp{1}{3};
                end
            end
            
            m=m+1;
        end
    end

end

gitInfo.url=url;
