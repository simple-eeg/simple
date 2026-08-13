%% step_3_sum_1_add_summaries.m
% Purpose:
%   - Read dataset_list.csv
%   - Create/overwrite a new column 'path_summary' by transforming
%       path_processed: '^data/processed' -> 'data/summary'
%   - Skip rows where path_processed is empty
%   - If path_processed starts with 'data/summary', copy as-is (no warning)
%   - If path_processed is non-empty but does not start with 'data/processed'
%       or 'data/summary', WARN and copy as-is
%   - Remove any existing 'path_summary' column first, then append it at the end
%
% Notes:
%   - Idempotent: column is rebuilt from path_processed on every run
%   - No folder creation here
%   - No inclusion/exclusion logic beyond empty path_processed

clear; clc;

%% Paths
baseDir      = resolve_framework_project('step_3_sum_1_add_summaries.m');
log_command_window('start');
fileListPath = fullfile(baseDir, 'data_lists', 'dataset_list.csv');

fprintf('Loading: %s\n', fileListPath);

%% Load spreadsheet with string-preserving options (force ALL columns to string)
opts = detectImportOptions(fileListPath, 'PreserveVariableNames', true, 'TextType', 'string', 'Delimiter', ',');

% Force every column to import as string (prevents loss of leading zeros, digit-only IDs, etc.)
opts = setvartype(opts, opts.VariableNames, 'string');

T = readtable(fileListPath, opts);

%% Validate required input column
if ~any(strcmp(T.Properties.VariableNames, 'path_processed'))
    error('Missing required column in dataset_list.csv: path_processed');
end

%% Normalize input
T.path_processed = string(T.path_processed);
T.path_processed(ismissing(T.path_processed)) = "";

%% Prepare output
N = height(T);
path_summary   = strings(N,1);
updated        = 0;
skipped_empty  = 0;
warned         = 0;

%% Build path_summary from path_processed
for r = 1:N
    p = strtrim(T.path_processed(r));

    if p == ""
        % Skip empties
        path_summary(r) = "";
        skipped_empty = skipped_empty + 1;
        continue
    end

    if startsWith(p, "data/processed")
        % Prefix swap
        path_summary(r) = regexprep(p, '^data/processed', 'data/summary');
        updated = updated + 1;

    else
        % Nonstandard root; warn and copy as-is
        fprintf('[warn] Row %d: path_processed does not start with "data/processed": %s\n', r, p);
        path_summary(r) = p;
        warned = warned + 1;
    end
end

%% Append/overwrite column at the END (keep stable order)
if any(strcmp(T.Properties.VariableNames, 'path_summary'))
    T = removevars(T, 'path_summary');
end
T.path_summary = path_summary;

%% Save
writetable(T, fileListPath);

%% Summary
fprintf('Done. path_summary updated/appended.\n');
fprintf('  Updated (from data/processed): %d\n', updated);
fprintf('  Skipped (empty path_processed): %d\n', skipped_empty);
fprintf('  Warned (nonstandard roots copied as-is): %d\n', warned);
fprintf('  Total rows: %d\n', N);

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
