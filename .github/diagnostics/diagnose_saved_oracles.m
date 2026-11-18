function diagnose_saved_oracles(repoRoot, eeglabRoot)
%DIAGNOSE_SAVED_ORACLES Report exact reference differences after a CI failure.
% This temporary diagnostic does not replace the regression suite or change
% its acceptance criteria. It reads the existing synthetic fixtures only.

originalPath = path;
pathCleanup = onCleanup(@() path(originalPath)); %#ok<NASGU>
warningState = warning;
warningCleanup = onCleanup(@() warning(warningState)); %#ok<NASGU>
restoredefaultpath;
addpath(eeglabRoot, '-begin');
eeglab nogui;
testsRoot = fullfile(repoRoot, 'tests');
addpath(fullfile(repoRoot, 'functions'), '-begin');
basePath = path;
loaded = load(fullfile(testsRoot, 'fixtures', ...
    'simple_scientific_oracle_v1.mat'), 'oracle');
oracle = loaded.oracle;
fprintf('DIAGNOSTIC MATLAB: %s; architecture: %s; EEGLAB: %s\n', ...
    version, computer, eeg_getversion);

groups = {'preproc', 'response', 'jitter', 'qc_coordinator', 'qc_direct'};
caseGroups = {oracle.preproc, oracle.response.cases, oracle.jitter, ...
    oracle.qc.coordinator, oracle.qc.direct};
caseCount = 0;
mismatchedCases = 0;
totalDifferences = 0;
for groupIndex = 1:numel(groups)
    kind = groups{groupIndex};
    cases = caseGroups{groupIndex};
    for caseIndex = 1:numel(cases)
        testCase = cases(caseIndex);
        path(basePath);
        clear preproc pop_cleanline pop_epoch pop_eegfiltnew pop_rmbase ...
            estimate_response jittercorrect quality_control_features
        if strcmp(kind, 'preproc')
            prepare_preproc_case(testCase.name, testsRoot);
        end
        rehash path;
        if isfield(testCase, 'name')
            name = testCase.name;
        else
            name = [testCase.calculator '/' testCase.case_name];
        end
        label = [kind '/' name];
        [output, failure, warningMessage, warningIdentifier] = ...
            invoke_case(kind, testCase);
        differences = compare_values(failure.identifier, ...
            testCase.error_identifier, [label '.error_identifier']);
        differences = differences + compare_values(failure.message, ...
            testCase.error_message, [label '.error_message']);
        if isfield(testCase, 'warning_message')
            differences = differences + compare_values(warningMessage, ...
                testCase.warning_message, [label '.warning_message']);
            differences = differences + compare_values(warningIdentifier, ...
                testCase.warning_identifier, [label '.warning_identifier']);
        end
        if isempty(testCase.error_identifier) && isempty(testCase.error_message)
            differences = differences + compare_values(output, ...
                testCase.output, [label '.output']);
        end
        if strcmp(kind, 'response') && isempty(failure.identifier) && ...
                isempty(failure.message) && ~isempty(fieldnames(testCase.numeric_input))
            fit = output.epoch(1).(testCase.options.NRFName);
            actualNumeric = {fit.pearsonR, fit.shifted_data_all, fit.shift_all, ...
                fit.NRF_resampled, fit.cosineSimilarity, fit.fglsCoef, ...
                fit.fglsVarCoef, fit.olsCoef};
            differences = differences + compare_values(actualNumeric, ...
                testCase.numeric_output, [label '.numeric_mapping']);
        end
        caseCount = caseCount + 1;
        mismatchedCases = mismatchedCases + (differences > 0);
        totalDifferences = totalDifferences + differences;
        fprintf('DIAGNOSTIC CASE %s: exact_match=%d; differing_fields=%d\n', ...
            label, differences == 0, differences);
    end
end
fprintf('DIAGNOSTIC SUMMARY cases=%d; mismatched_cases=%d; differing_fields=%d\n', ...
    caseCount, mismatchedCases, totalDifferences);
assert(totalDifferences == 0, ...
    'Saved synthetic reference differences remain; no tolerance was applied.');
end

function prepare_preproc_case(name, testsRoot)
switch name
    case 'filter_empty_command'
        stub = 'filter_empty_command';
    case 'cleanline_empty_command'
        stub = 'cleanline_empty';
    case 'cleanline_other_error'
        stub = 'cleanline_error';
    case 'epoch_other_error'
        stub = 'epoch_error';
    case 'epoch_empty_command'
        stub = 'epoch_empty_command';
    case 'baseline_other_error'
        stub = 'baseline_error';
    case 'cleanline_undefined_fallback'
        locations = which('pop_cleanline', '-all');
        if ischar(locations)
            locations = cellstr(locations);
        end
        for index = 1:numel(locations)
            rmpath(fileparts(locations{index}));
        end
        assert(isempty(which('pop_cleanline')));
        return;
    otherwise
        return;
end
addpath(fullfile(testsRoot, 'stubs', stub), '-begin');
end

function [output, failure, warningMessage, warningIdentifier] = invoke_case(kind, testCase)
output = [];
failure = struct('identifier', '', 'message', '');
lastwarn('', '');
try
    switch kind
        case 'preproc'
            if strcmp(testCase.name, 'no_arguments')
                captured = evalc('preproc();'); %#ok<NASGU>
            elseif strcmp(testCase.name, 'options_required')
                captured = evalc('output = preproc(testCase.input);'); %#ok<NASGU>
            else
                captured = evalc('output = preproc(testCase.input, testCase.options);'); %#ok<NASGU>
            end
        case 'response'
            if strcmp(testCase.name, 'options_required')
                captured = evalc('output = estimate_response(testCase.input);'); %#ok<NASGU>
            else
                captured = evalc('output = estimate_response(testCase.input, testCase.options);'); %#ok<NASGU>
            end
        case 'jitter'
            output = cell(1, 3);
            captured = evalc(['[output{:}] = jittercorrect(testCase.data, testCase.NRF, ' ...
                'testCase.fs, testCase.fs_NRF, testCase.jitter_ms, testCase.start_ms);']); %#ok<NASGU>
        case 'qc_coordinator'
            captured = evalc('output = quality_control_features(testCase.input);'); %#ok<NASGU>
        case 'qc_direct'
            captured = evalc('output = feval(testCase.calculator, testCase.data, testCase.Fs, testCase.t_ms);'); %#ok<NASGU>
    end
catch exception
    failure.identifier = exception.identifier;
    failure.message = exception.message;
    if strcmp(kind, 'jitter')
        output = {};
    end
end
[warningMessage, warningIdentifier] = lastwarn;
end

function count = compare_values(actual, expected, location)
count = 0;
if isequaln(actual, expected)
    return;
end
if ~strcmp(class(actual), class(expected)) || ~isequal(size(actual), size(expected))
    fprintf('DIAGNOSTIC DIFFERENCE %s: class=%s/%s; size=%s/%s\n', ...
        location, class(actual), class(expected), mat2str(size(actual)), ...
        mat2str(size(expected)));
    count = 1;
elseif isstruct(actual)
    fields = union(fieldnames(actual), fieldnames(expected), 'stable');
    for element = 1:numel(actual)
        for index = 1:numel(fields)
            field = fields{index};
            child = sprintf('%s(%d).%s', location, element, field);
            if ~isfield(actual, field) || ~isfield(expected, field)
                fprintf('DIAGNOSTIC DIFFERENCE %s: field present=%d/%d\n', ...
                    child, isfield(actual, field), isfield(expected, field));
                count = count + 1;
            else
                count = count + compare_values(actual(element).(field), ...
                    expected(element).(field), child);
            end
        end
    end
elseif iscell(actual)
    for index = 1:numel(actual)
        count = count + compare_values(actual{index}, expected{index}, ...
            sprintf('%s{%d}', location, index));
    end
elseif isnumeric(actual)
    a = double(actual(:));
    b = double(expected(:));
    fprintf(['DIAGNOSTIC DIFFERENCE %s: class=%s; size=%s; max_abs_delta=%.17g; ' ...
        'actual_max=%.17g; expected_max=%.17g; nan_positions_match=%d; ' ...
        'inf_positions_match=%d\n'], location, class(actual), mat2str(size(actual)), ...
        max(abs(a - b), [], 'omitnan'), max(abs(a), [], 'omitnan'), ...
        max(abs(b), [], 'omitnan'), isequal(isnan(a), isnan(b)), ...
        isequal(isinf(a), isinf(b)));
    count = 1;
else
    fprintf('DIAGNOSTIC DIFFERENCE %s: class=%s; size=%s\n', ...
        location, class(actual), mat2str(size(actual)));
    disp(actual);
    disp(expected);
    count = 1;
end
end
