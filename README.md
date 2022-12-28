# Decision Curve Analysis with SAS

This repository contains two SAS macros to generate decison curve anlaysis figures in SAS.
- `dca.sas` Create a DCA figure for models with binary endpoints
- `stdca.sas` Create a DCA figure for models with time-to-event endpoints

For detailed vignettes and examples of DCA in action using Stata, R and SAS, visit [decisioncurveanalysis.org](decisioncurveanalysis.org).

Source the DCA SAS macros with

```sas
filename dca url "https://raw.githubusercontent.com/ddsjoberg/dca.sas/main/dca.sas";
filename stdca url "https://raw.githubusercontent.com/ddsjoberg/dca.sas/main/stdca.sas";
%include dca;
%include stdca;
```

Call the macros with

```sas
%DCA(...)
%STDCA(...)
```

## Unit Testing

1. Confirm the directory settings in `unit-testing/tests.sas` are correct.
1. Run the file `unit-testing/tests.sas`. This will...
    - Source the current versions of `dca.sas` and `stdca.sas`.
    - Create and ODS report of with `PROC COMPARE` showing the expected results against the obtained results.
1. Confirm the output in the ODS report.

## Release History

#### v0.4.0 (2022-12-28)

* The net interventions avoided figures have new defaults (breaking change):
  * The figure will now include the treat all and treat none reference lines.
  * The nper now defaults to one.

#### v0.3.0 (2021-11-16)

* Added `prevalence=` argument to the `%DCA()` macro. Users working with case-control data can now specify the population prevalence.

* Cleaning up functions so no additional data sets are saved to the work library.

* Added unit testing.

#### v0.2.1 (2021-06-23)

* Bug fix in `%STDCA()`

#### v0.2.0 (2015-02-02)

* Initial release.
