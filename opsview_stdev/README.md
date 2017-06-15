opsview_stdev.pm
======

How does one determine when a service check value is out of bounds.  Static thresholds are one way.  Percentiles are another.  And the standard deviation is yet another.  This code polls the Opsview API for nagios perf data.  That is stored from previous calls to the service check.  It is run every 5 minutes by default.  Then the stdev is calculated.  If the service check value is greater or less than the perf data average + ( stdev * 2), then an alert is returned.  This satisfies the 68–95–99.7 rule, for finding abnormal values in a data set.

During an Expedia phone interview I was asked the difference between stev and percentiles.  Using data average + ( stdev * 2) allows you to calculate the percentiles at which anomalies begin.  This, of course is superior to flat percentiles.
