check_auto_increment.pl
======

MySQL auto increment integers are finite.  This service check was create to monitor how close they are to their respective maximums.  It examines all tables in a databases.  Looking for auto increment columns.  When they are found, a select max is done.  Which returns instantly since auto increment integrers are always indexed.
