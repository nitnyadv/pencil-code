;;;;;;;;;;;;;;;;;;;
;;;  start.pro  ;;;
;;;;;;;;;;;;;;;;;;;
;;;
;;; Initialise coordinate arrays, detect precision and dimensions.
;;; Typically run only once before running `r.pro' and other
;;; plotting/analysing scripts.

common cdat,x,y,z,mx,my,mz,nw,ntmax,date0,time0
;
@xder_6th_ghost
@yder_6th_ghost
@zder_6th_ghost
@xder2_6th_ghost
@yder2_6th_ghost
@zder2_6th_ghost
;
default, proc, 0
default, datatopdir, 'tmp'
default, file, 'var.dat'
datadir=datatopdir+'/proc'+str(proc)
;
;  Read the dimensions and precision (single or double) from dim.dat
;
mx=0L & my=0L & mz=0L & nvar=0L
prec=''
nghostx=0L & nghosty=0L & nghostz=0L
;
close,1
openr,1,datadir+'/'+'dim.dat'
readf,1,mx,my,mz,nvar
readf,1,prec
readf,1,nghostx,nghosty,nghostz
close,1
;
mw=mx*my*mz  ;(this must be calculated; its not in dim.dat)
prec = (strtrim(prec,2))        ; drop leading zeros
prec = strmid(prec,0,1)
if ((prec eq 'S') or (prec eq 's')) then begin
  one = 1.e0
endif else if ((prec eq 'D') or (prec eq 'd')) then begin
  one = 1.D0
endif else begin
  print, "prec = `", prec, "' makes no sense to me"
  STOP
endelse
zero = 0*one
;
;  Read startup parameters
;
x0=(y0=(z0=zero))
Lx=(Ly=(Lz=zero))
cs0=(gamma=(gamma1=zero))
gravz=(rho0=(grads0=zero))
z1=(z2=(z3=zero))
hcond0=(hcond1=(hcond2=(whcond=zero)))
mpoly0=(mpoly1=(mpoly2=zero))
isothtop=0L
bx_ext=(by_ext=(bz_ext=zero))
lgravz=(lgravr=0L)
lentropy=(lmagnetic=(lforcing=0L))
;
pfile=datatopdir+'/'+'param.dat'
dummy=findfile(pfile, COUNT=cpar)
if (cpar gt 0) then begin
  print, 'Reading param.dat..'
  openr,1, pfile, /F77
  readu,1, x0,y0,z0,Lx,Ly,Lz
  readu,1, cs0,gamma,gamma1
  readu,1, gravz,rho0,grads0
  readu,1, z1,z2,ztop
  readu,1, hcond0,hcond1,hcond2,whcond
  readu,1, mpoly0,mpoly1,mpoly2,isothtop
  readu,1, lgravz,lgravr,lentropy,lmagnetic,lforcing
  close,1
endif else begin
  print, 'Warning: cannot find file ', pfile
endelse
;
;  Read grid
;
t=zero
x=fltarr(mx)*one & y=fltarr(my)*one & z=fltarr(mz)*one
dx=zero &  dy=zero &  dz=zero & dxyz=zero
gfile=datadir+'/'+'grid.dat'
dummy=findfile(gfile, COUNT=cgrid)
if (cgrid gt 0) then begin
  print, 'Reading grid.dat..'
  openr,1, gfile, /F77
  readu,1, t,x,y,z
  readu,1, dx,dy,dz
  close,1
endif else begin
  print, 'Warning: cannot find file ', gfile
endelse
;
;print,'calculating xx,yy,zz (comment this out if there is not enough memory)'
;xx = spread(x, [1,2], [my,mz])
;yy = spread(y, [0,2], [mx,mz])
;zz = spread(z, [0,1], [mx,my])
;
;  set boundary values for physical (sub)domain
;
l1=3 & l2=mx-4
m1=3 & m2=my-4
n1=3 & n2=mz-4
;
print, '..done'
;
started=1
END
