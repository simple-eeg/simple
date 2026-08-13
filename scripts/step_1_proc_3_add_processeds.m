%% step_1_proc_3_add_processeds.m
% Purpose:
%   - Read dataset_list.csv
%   - For each row (ALL rows treated as included):
%       * Set/overwrite:
%           - EEGfile_processed = EEGfile_raw
%           - path_processed    = path_raw with leading 'data/raw' -> 'data/processed'
%   - Append the processed columns at the end of the table (remove existing first to keep order):
%     path_processed, then EEGfile_processed
%
% Notes:
%   - Idempotent: safe to re-run; columns are re-derived and re-appended at the end
%   - No folder creation here (that will happen in preprocessing)
%   - Expects the source columns to be present and non-empty for all rows

clear; clc;

%% Paths
baseDir      = resolve_framework_project('step_1_proc_3_add_processeds.m');
log_command_window('start');
fileListPath = fullfile(baseDir, 'data_lists', 'dataset_list.csv');

%% Load dataset_list.csv
fprintf('Loading: %s\n', fileListPath);
opts = detectImportOptions(fileListPath, 'PreserveVariableNames', true, 'TextType', 'string', 'Delimiter', ',');

% Force ALL columns to import as string (prevents loss of leading zeros, digit-only IDs, etc.)
opts = setvartype(opts, opts.VariableNames, 'string');

T = readtable(fileListPath, opts);

% Ensure required columns exist
requiredCols = {'EEGfile_raw','path_raw'};
missingCols = setdiff(requiredCols, T.Properties.VariableNames);
if ~isempty(missingCols)
    error('Missing required columns in dataset_list.csv: %s', strjoin(missingCols, ', '));
end

N = height(T);

%% Prepare outputs
EEGfile_processed = strings(N,1);
path_processed    = strings(N,1);

checked = 0;
updated = 0;

%% Iterate rows
for r = 1:N

    % Included row: source fields must be present
    srcName = strtrim(string(T.EEGfile_raw(r)));
    srcPath = strtrim(string(T.path_raw(r)));
    if strlength(srcName) == 0 || strlength(srcPath) == 0
        error('Row %d has empty EEGfile_raw or path_raw.', r);
    end

    % Derive processed name/path
    EEGfile_processed(r) = srcName;  % same filename
    % Prefix swap only: '^data/raw' -> 'data/processed'
    dstPath = regexprep(srcPath, '^data/raw', 'data/processed');

    % Optional sanity: warn if prefix wasn't matched (path didn't start with data/raw)
    if ~startsWith(srcPath, "data/raw")
        fprintf('[warn] Row %d: path_raw does not start with "data/raw": %s\n', r, srcPath);
    end

    path_processed(r) = dstPath;

    checked = checked + 1;
    updated = updated + 1;
end

%% Append/overwrite columns at the END (keep stable order)
toRemove = intersect({'path_processed','EEGfile_processed'}, T.Properties.VariableNames);
if ~isempty(toRemove)
    T = removevars(T, toRemove);
end
T.path_processed    = path_processed;
T.EEGfile_processed = EEGfile_processed;

%% Save
writetable(T, fileListPath);

fprintf('Done. Rows updated: %d | Total rows: %d\n', updated, N);

log_command_window('stop');

function baseDir = resolve_framework_project(expectedScriptName)
% Resolve this saved script's repository root without a personal fallback.
scriptFile = mfilename('fullpath');
localSeparator = strfind(scriptFile, '>');
if ~isempty(localSeparator)
    scriptFile = scriptFile(1:localSeparator(1)-1);
end
if ~endsWith(scriptFile, '.m', 'IgnoreCase', true)
    scriptFile = [scriptFile '.m'];
end
scriptsDir = fileparts(scriptFile);
[baseDir, scriptsLeaf] = fileparts(scriptsDir);
expectedScriptPath = fullfile(scriptsDir, expectedScriptName);
functionsDir = fullfile(baseDir, 'functions');
loggerPath = fullfile(scriptsDir, 'log_command_window.m');
if isempty(scriptFile) || ~strcmp(scriptsLeaf, 'scripts') || ...
        ~isfile(expectedScriptPath) || ...
        ~strcmp(char(java.io.File(scriptFile).getCanonicalPath()), ...
                char(java.io.File(expectedScriptPath).getCanonicalPath())) || ...
        ~isfolder(functionsDir) || ~isfolder(fullfile(baseDir, 'data_lists')) || ...
        ~isfile(loggerPath) || ~isfile(fullfile(baseDir, 'README.md'))
    error('SIMPLE:UnableToResolveProjectRoot', ...
        'Run this saved framework script from its repository scripts directory.');
end
addpath(scriptsDir, '-begin');
addpath(functionsDir, '-begin');
clear log_command_window
resolvedLogger = which('log_command_window');
if isempty(resolvedLogger) || ...
        ~strcmp(char(java.io.File(resolvedLogger).getCanonicalPath()), ...
                char(java.io.File(loggerPath).getCanonicalPath()))
    error('SIMPLE:UnableToResolveProjectRoot', ...
        'The repository-local log_command_window.m could not be resolved deterministically.');
end
end
