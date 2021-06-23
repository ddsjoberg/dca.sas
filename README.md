# Decision Curve Analysis with SAS

Source the DCA SAS macros with

```sas
filename dca url "https://raw.githubusercontent.com/ddsjoberg/dca.sas/main/dca.sas";
filename stdca url "https://raw.githubusercontent.com/ddsjoberg/dca.sas/main/stdca.sas";
%include dca;
%include stdca;
```

More details and tutorials at http://decisioncurveanalysis.org/
