! $Id: ionization.f90,v 1.8 2003-02-23 07:41:27 brandenb Exp $

!  This modules contains the routines for simulation with
!  simple hydrogen ionization.

module Ionization

  use Cparam
  use Cdata
  use Density

  implicit none

  !  secondary parameters calculated in initialize
  real :: lnTT_ion,lnrho_ion,ss_ion

  ! to be deleted
  real :: chiH,nqe,nqp

  !  lionization initialized to .true.
  !  it can be reset to .false. in namelist
  logical :: lionization=.true.

  ! input parameters
  integer :: dummy 
  namelist /ionization_init_pars/ lionization

  ! run parameters
  namelist /ionization_run_pars/ lionization

  contains

!***********************************************************************
    subroutine register_ionization()
!
!   2-feb-03/axel: adapted from Interstellar module
!
      use Cdata
      use Mpicomm, only: stop_it
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_ionization called twice')
      first = .false.
!
      if ((ip<=8) .and. lroot) then
        print*, 'Register_ionization'
      endif
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: ionization.f90,v 1.8 2003-02-23 07:41:27 brandenb Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('Register_ionization: nvar > mvar')
      endif
!
    endsubroutine register_ionization

!***********************************************************************
    subroutine initialize_ionization()
!
!  Perform any post-parameter-read initialization, e.g. set derived 
!  parameters.
!
!   2-feb-03/axel: adapted from Interstellar module
!
      use Cdata
      use General
!
      logical, save :: first=.true.
      logical :: exist
!
!  ionization parameters
!  since m_e and chiH, as well as hbar are all very small
!  it is better to divide m_e and chiH separately by hbar.
!
      chiH=13.6*eV
      lnTT_ion=log(chiH/k_B)
      lnrho_ion=1.5*log((m_e/hbar)*(chiH/hbar)/(2*pi))+log(m_p+m_e)
      ss_ion=k_B/m_p
      if(lroot) then
        print*,'initialize_ionization: reference values for ionization'
        print*,'lnTT_ion,exp(lnTT_ion)=',lnTT_ion,exp(lnTT_ion)
        print*,'lnrho_ion,exp(lnrho_ion)=',lnrho_ion,exp(lnrho_ion)
        print*,'ss_ion=',ss_ion
      endif
!
!  to be removed
!AB: Tobi, can you do that when you are done?
!
      nqe=2.414703e15
      nqp=1.899883e20
!
    endsubroutine initialize_ionization

!***********************************************************************
    subroutine thermodynamics(lnrho,ss,cs2,TT1,cp1tilde)
!
!  Calculate thermodynamical quantities, cs2, 1/T, and cp1tilde
!  cs2=(dp/drho)_s is the adiabatic sound speed
!  TT1=1/T is the inverse temperature
!  neutral gas: cp1tilde=ss_ion/cp=0.4 ("nabla_ad" maybe better name)
!  in general: cp1tilde=dlnPdS/dlnPdlnrho
!
!   2-feb-03/axel: simple example coded
!
      use Cdata
      use General
      use Sub
!
      real, dimension (nx) :: lnrho,ss,rho1,cs2,TT1,cp1tilde
      real, dimension (nx) :: yH,logTT,dlnPdlnrho,dlnPdS,TT,rho,ee
      real :: ss0=-5.5542
!
!  calculate cs2, 1/T, and cp1tilde
!
      if(lionization) then
        if(headtt) print*,'thermodynamics: assume cp is not 1'
        call pressure_gradient(lnrho,ss,dlnPdlnrho,dlnPdS)
        call logtemperature(lnrho,ss,yH,logTT)
        TT=exp(logTT); TT1=1./TT
!AB: Tobi plans to measure entropy in physical units, and not in kB/mp
!AB: until this is the case, we cannot use T1=1/T, but have to use
!AB: TT1=1/(ss_ion*TT)
        TT1=TT1/ss_ion
! later: change logTT to TT and logtemperature to temperature
        cs2=(1.+yH)*ss_ion*TT*dlnPdlnrho
        cp1tilde=dlnPdS/dlnPdlnrho
        if (ldiagnos.and.i_eth/=0) then
          rho=exp(lnrho)
          ee=cs2/(gamma*gamma1) !(not correct with ionization)
          call sum_mn_name(rho*ee,i_eth)
        endif
      else
!
!  new case: cp-cv=1, ie cp=2.5
!
        if(headtt) print*,'thermodynamics: assume cp-cv=1 and cp=2.5'
        dlnPdlnrho=gamma
        dlnPdS=gamma1
        logTT=gamma1*(lnrho+ss-ss0)
        TT=exp(logTT); TT1=1./TT
        cs2=ss_ion*TT*dlnPdlnrho
        cp1tilde=dlnPdS/dlnPdlnrho
        if (ldiagnos.and.i_eth/=0) then
          rho=exp(lnrho)
          ee=cs2/(gamma*gamma1) !(not correct with ionization)
          call sum_mn_name(rho*ee,i_eth)
        endif
      endif
!
    endsubroutine thermodynamics

!***********************************************************************
    subroutine pressure_gradient(lnrho,ss,dlnPdlnrho,dlnPdS)
!
!   3-feb-03/tobi: coded
!
      real, dimension(nx),intent(in)   :: lnrho,ss
      real, dimension(nx), intent(out) :: dlnPdlnrho,dlnPdS
      real, dimension(nx)              :: dlnrho,dss

      dlnrho=1.e-3*lnrho
      dlnPdlnrho=(logpressure(lnrho+dlnrho,ss) &
           -logpressure(lnrho-dlnrho,ss))/(2.*dlnrho)
      dss=1.e-3*ss
      dlnPdS=(logpressure(lnrho,ss+dss) &
           -logpressure(lnrho,ss-dss))/(2.*dss)
    endsubroutine pressure_gradient

!***********************************************************************
    function logpressure(lnrho,ss)
!
!   3-feb-03/tobi: coded
!
      real, dimension(nx), intent(in) :: lnrho,ss
      real, dimension(nx)             :: yH,logTT,logpressure

      call logtemperature(lnrho,ss,yH,logTT)
      logpressure=lnrho+log(1.+yH)+logTT
    endfunction logpressure

!***********************************************************************
    subroutine logtemperature(lnrho,ss,yH,logTT)
!
!   3-feb-03/tobi: coded
!
      real, dimension(nx), intent(in)  :: lnrho,ss
      real, dimension(nx) ,intent(out) :: yH,logTT

      yH=ionfrac(lnrho,ss)
      logTT=2.*(ss-log(nqp)-yH*log(nqe) &
           -(1.+yH)*(2.5+log(m_p)-lnrho) &
           +(1.-yH)*log(1.-yH)+2.*yH*log(yH))/(3.+3.*yH)
    endsubroutine logtemperature

!***********************************************************************
    function ionfrac(lnrho,ss)
!
!   3-feb-03/tobi: coded
!
      real, dimension(nx) :: lnrho,ss
      real, dimension(nx) :: ionfrac
      integer             :: i

      do i=1,nx
         ionfrac(i)=rtsafe(lnrho(i),ss(i))
      enddo
    endfunction ionfrac

!***********************************************************************
    function rtsafe(lnrho,ss)
!
!   3-feb-03/tobi: coded
!
      real, intent (in)  :: lnrho,ss
      real               :: yH_h,yH_l,dyH_old,dyH,fl,fh,f,df,temp,rtsafe
      real, parameter    :: yH_acc=1.e-5
      real, save         :: yH_last=.5
      integer            :: i
      integer, parameter :: maxit=100

      yH_l=1.-yH_acc
      yH_h=yH_acc
      dyH_old=1.
      dyH=dyH_old

      rtsafe=yH_acc
      call saha(rtsafe,lnrho,ss,fl,df)
      if (fl.le.0.) then
         rtsafe=yH_acc
         return
      endif
      rtsafe=1.-yH_acc
      call saha(rtsafe,lnrho,ss,fh,df)
      if (fh.ge.0.) then
         yH_last=rtsafe
         return
      endif
    
      rtsafe=yH_last
      call saha(rtsafe,lnrho,ss,f,df)

      do i=1,maxit
         if (((rtsafe-yH_h)*df-f)*((rtsafe-yH_l)*df-f).gt.0. &
              .or.abs(2.*f).gt.abs(dyH_old*df)) then
            dyH_old=dyH
            dyH=.5*(yH_h-yH_l)
            rtsafe=yH_l+dyH
            if (yH_l.eq.rtsafe) then
               yH_last=rtsafe
               !niter=niter+i
               return
            endif
         else
            dyH_old=dyH
            dyH=f/df
            temp=rtsafe
            rtsafe=rtsafe-dyH
            if (temp.eq.rtsafe) then
               yH_last=rtsafe
               !niter=niter+i
               return
            endif
         endif
         if (abs(dyH).lt.yH_acc) then
            yH_last=rtsafe
            !niter=niter+i
            return
         endif
         call saha(rtsafe,lnrho,ss,f,df)
         if (f.lt.0.) then
            yH_l=rtsafe
         else
            yH_h=rtsafe
         endif
      enddo
      print *,'rtsafe exceeded maximum iterations',f
    endfunction rtsafe

!***********************************************************************
    subroutine saha(yH,lnrho,ss,f,df)
!
!   3-feb-03/tobi: coded
!
      real, intent(in)  :: yH,lnrho,ss
      real, intent(out) :: f,df
      real              :: logTT,dlogTT

      logTT=2.*(ss/ss_ion-log(nqp)-yH*log(nqe)-(1.+yH)*(2.5+log(m_p)-lnrho) &
           +(1.-yH)*log(1.-yH)+2.*yH*log(yH))/(3.+3.*yH)
      dlogTT=2.*(lnrho-log(m_p)-log(nqe)+2.*log(yH) &
           -log(1.-yH)-1.5*(logTT+1.))/(3.+3.*yH)
      f=-chiH*exp(-logTT)/k_B-1.5*((1.+yH)*dlogTT+1.)
      df=dlogTT*(1.5+chiH*exp(-logTT)/k_B)-1./(1.-yH)-2./yH
    endsubroutine saha

endmodule ionization
