function report = detecdiv_catalog_run_raw_index_job(rawRoot, dbFile)
% detecdiv_catalog_run_raw_index_job  Background-safe wrapper around raw dataset indexing.

    report = detecdiv_catalog_index_raw_datasets(rawRoot, dbFile, ...
        'Verbose', false);
end
