# Decision Curve Analysis with SAS

This repository contains two SAS macros to generate decison curve anlaysis figures in SAS.
- `dca.sas` Create a DCA figure for models with binary endpoints
- `stdca.sas` Create a DCA figure for models with time-to-event endpoints

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

More details and tutorials at http://decisioncurveanalysis.org/
