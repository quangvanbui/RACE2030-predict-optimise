var 0..6: x;
var 0..20: y;
var 0..1: b;
var float: z1;
var float: z2;

constraint x <= 5;
constraint y <= 20;
constraint 2 * x <= y;
constraint z1 <= 10000.0 * x;
constraint z2 <= 0;
constraint b == bool2int(y > 8);
constraint z2 <= b * -20000;

solve maximize z1 + z2;
