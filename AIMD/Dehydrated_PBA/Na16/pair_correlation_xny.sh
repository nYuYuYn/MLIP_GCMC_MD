file=PCDAT
awk <$file >PCDAT.xy '
NR==8 { pcskal=$1}
NR==9 { pcfein=$1}
NR==7 { npaco=$1}
NR>=13 {  
  line=line+1
  if (line==1) s=s+1
  if (line==(npaco+1))  {
     print " "
     line=0
  }
  else  {
     a1[line]=  a1[line] + $1
     a2[line]=  a2[line] + $2
     a3[line]=  a3[line] + $3
     a4[line]=  a4[line] + $4
	 a5[line]=  a5[line] + $5
     a6[line]=  a6[line] + $6
     a7[line]=  a7[line] + $7
     a8[line]=  a8[line] + $8
	 a9[line]=  a9[line] + $9
     a10[line]=  a10[line] + $10
     a11[line]=  a11[line] + $11
     a12[line]=  a12[line] + $12
	 a13[line]=  a13[line] + $13
     a14[line]=  a14[line] + $14
     a15[line]=  a15[line] + $15
     print (line-0.5)*pcfein/pcskal,$1,$2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15
  }
}
END {
 print "final sets=", s
 for (line=1 ; line<=npaco ; line++)
     print (line-0.5)*pcfein/pcskal,a1[line]/s,a2[line]/s,a3[line]/s,a4[line]/s,a5[line]/s,a6[line]/s,a7[line]/s,a8[line]/s,a9[line]/s,a10[line]/s,a11[line]/s,a12[line]/s,a13[line]/s,a14[line]/s,a15[line]/s
}
'





























































