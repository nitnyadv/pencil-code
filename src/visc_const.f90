! $Id: visc_const.f90,v 1.47 2004-10-31 11:40:32 ajohan Exp $

!  This modules implements viscous heating and diffusion terms
!  here for cases 1) nu constant, 2) mu = rho.nu 3) constant and 

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Viscosity

  use Cparam
  use Cdata
  use Density

  implicit none

  character (len=labellen) :: ivisc='nu-const'
  integer :: i_dtnu=0
  real :: nu_mol

  ! dummy logical
  logical :: lvisc_first=.false.

  ! input parameters
  integer :: dummy1
  namelist /viscosity_init_pars/ dummy1

  ! run parameters
  namelist /viscosity_run_pars/ nu, ivisc, nu_mol, C_smag
 
  ! other variables (needs to be consistent with reset list below)
  integer :: i_epsK2=0

  contains

!***********************************************************************
    subroutine register_viscosity()
!
!  19-nov-02/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_viscosity called twice')
      first = .false.
!
      lviscosity = .true.
      lvisc_shock=.false.
!
      if ((ip<=8) .and. lroot) then
        print*, 'register_viscosity: constant viscosity'
      endif
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: visc_const.f90,v 1.47 2004-10-31 11:40:32 ajohan Exp $")


! Following test unnecessary as no extra variable is evolved
!
!      if (nvar > mvar) then
!        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
!        call stop_it('Register_viscosity: nvar > mvar')
!      endif
!
    endsubroutine register_viscosity
!***********************************************************************
    subroutine initialize_viscosity()
!
!  20-nov-02/tony: coded
!
      use Cdata
!
!  Some viscosity types need the rate-of-strain tensor and grad(lnrho)
!
      if (((ivisc=='nu-const' .or. ivisc=='hyper3_nu-const') .and. nu/=0.) &
          .or. (ivisc=='smagorinsky_simplified')) then
        lneed_sij=.true.
        lneed_glnrho=.true.
      endif
!
    endsubroutine initialize_viscosity
!*******************************************************************
    subroutine rprint_viscosity(lreset,lwrite)
!
!  Writes ishock to index.pro file
!
!  24-nov-03/tony: adapted from rprint_ionization
!
      use Cdata
      use Sub
! 
      logical :: lreset
      logical, optional :: lwrite
      integer :: iname
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        i_dtnu=0
        i_nu_LES=0
        i_epsK2=0
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      if(lroot.and.ip<14) print*,'rprint_viscosity: run through parse list'
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'dtnu',i_dtnu)
        call parse_name(iname,cname(iname),cform(iname),'nu_LES',i_nu_LES)
        call parse_name(iname,cname(iname),cform(iname),'epsK2',i_epsK2)
      enddo
!
!  write column where which ionization variable is stored
!
      if (present(lwrite)) then
        if (lwrite) then
          write(3,*) 'i_dtnu=',i_dtnu
          write(3,*) 'i_nu_LES=',i_nu_LES
          write(3,*) 'ihyper=',ihyper
          write(3,*) 'ishock=',ishock
          write(3,*) 'i_epsK2=',i_epsK2
          write(3,*) 'itest=',0
        endif
      endif
!   
      if(ip==0) print*,lreset  !(to keep compiler quiet)
    endsubroutine rprint_viscosity
!!***********************************************************************
    subroutine calc_viscosity(f)
      real, dimension (mx,my,mz,mvar+maux) :: f
      if(ip==0) print*,f  !(to keep compiler quiet)
    endsubroutine calc_viscosity
!!***********************************************************************
    subroutine calc_viscous_heat(f,df,glnrho,divu,rho1,cs2,TT1,shock)
!
!  calculate viscous heating term for right hand side of entropy equation
!
!  20-nov-02/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub

      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx)   :: rho1,TT1,cs2
      real, dimension (nx)   :: sij2, divu,shock
      real, dimension (nx,3) :: glnrho
!
!  traceless strain matrix squared
!
      call multm2_mn(sij,sij2)
!
      select case(ivisc)
       case ('simplified', '0')
         if (headtt) print*,'no heating: ivisc=',ivisc
       case('rho_nu-const', '1')
         if (headtt) print*,'viscous heating: ivisc=',ivisc
         df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + TT1*2.*nu*sij2*rho1
       case('nu-const', '2')
         if (headtt) print*,'viscous heating: ivisc=',ivisc
         df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + TT1*2.*nu*sij2
       case default
         if (lroot) print*,'ivisc=',trim(ivisc),' -- this could never happen'
         call stop_it("")
      endselect
      if(ip==0) print*,f,cs2,divu,glnrho,shock  !(keep compiler quiet)
    endsubroutine calc_viscous_heat

!***********************************************************************
    subroutine calc_viscous_force(f,df,glnrho,divu,rho1,shock,gshock,bij)
!
!  calculate viscous heating term for right hand side of entropy equation
!
!  20-nov-02/tony: coded
!   9-jul-04/nils: added Smagorinsky viscosity
!
      use Cdata
      use Mpicomm
      use Sub

      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3,3) :: bij,Jij
      real, dimension (nx,3) :: glnrho,del2u,del6u,graddivu,fvisc,sglnrho
      real, dimension (nx,3) :: nusglnrho,tmp1,tmp2,gshock
      real, dimension (nx) :: murho1,rho1,divu,shock,SS12,nu_smag,sij2
      real, dimension (nx) :: ufvisc,rufvisc,SJ
      integer :: i,j

      intent (in) :: f, glnrho, rho1
      intent (out) :: df,shock,gshock
!
!  viscosity operator
!  rho1 is pre-calculated in equ
!
      shock=0.
      gshock=0.

      if ((nu /= 0.) .or. (ivisc == 'smagorinsky_simplified')) then
        select case (ivisc)

        case ('simplified', '0')
          !
          !  viscous force: nu*del2v
          !  -- not physically correct (no momentum conservation), but
          !  numerically easy and in most cases qualitatively OK
          !
          if (headtt) print*,'viscous force: nu*del2v'
          call del2v(f,iuu,del2u)
          fvisc=nu*del2u
          !call max_for_dt(nu,maxdiffus)
          diffus_nu=max(diffus_nu,nu*dxyz_2)

        case('rho_nu-const', '1')
          !
          !  viscous force: mu/rho*(del2u+graddivu/3)
          !  -- the correct expression for rho*nu=const (=rho0*nu)
          !
          if (headtt) print*,'viscous force: mu/rho*(del2u+graddivu/3)'
          murho1=(nu*rho0)*rho1  !(=mu/rho)
          call del2v_etc(f,iuu,del2u,GRADDIV=graddivu)
          do i=1,3
            fvisc(:,i)=murho1*(del2u(:,i)+1./3.*graddivu(:,i))
          enddo
          diffus_nu=max(diffus_nu,murho1*dxyz_2)

        case('nu-const')
          !
          !  viscous force: nu*(del2u+graddivu/3+2S.glnrho)
          !  -- the correct expression for nu=const
          !
          if (headtt) print*,'viscous force: nu*(del2u+graddivu/3+2S.glnrho)'
          call del2v_etc(f,iuu,del2u,GRADDIV=graddivu)
          if(ldensity) then
            call multmv_mn(sij,glnrho,sglnrho)
            fvisc=2*nu*sglnrho+nu*(del2u+1./3.*graddivu)
          else
            fvisc=nu*(del2u+1./3.*graddivu)
          endif
          diffus_nu=max(diffus_nu,nu*dxyz_2)

        case ('hyper3_simplified', 'hyper6')
          !
          !  viscous force: nu*del6v (not momentum-conserving)
          !
          if (headtt) print*,'viscous force: nu*del6v'
          call del6v(f,iuu,del6u)
          fvisc=nu*del6u
!          call max_for_dt(nu,maxdiffus)
          diffus_nu=max(diffus_nu,nu*dxyz_2)

        case ('hyper3_rho_nu-const')
          !
          !  viscous force: mu/rho*del6u
          !
          if (headtt) print*,'viscous force: mu/rho*del6v'
          call del6v(f,iuu,del6u)
          murho1=(nu*rho0)*rho1  !(=mu/rho)
          do i=1,3
            fvisc(:,i)=murho1*del6u(:,i)
          enddo
          diffus_nu=max(diffus_nu,nu*dxyz_2)

        case ('hyper3_nu-const')
          !
          !  viscous force: nu*(del6u+S.glnrho), where S_ij=d^5 u_i/dx_j^5
          !
          if (headtt) print*,'viscous force: nu*(del6u+S.glnrho)'
          call del6v(f,iuu,del6u)
          call multmv_mn(sij,glnrho,sglnrho)
          fvisc=nu*(del6u+sglnrho)
          diffus_nu=max(diffus_nu,nu*dxyz_2)

        case ('smagorinsky_simplified')
          !
          !  viscous force: nu_smag*(del2u+graddivu/3+2S.glnrho)
          !  where nu_smag=(C_smag*dxmax)**2*sqrt(2*SS)
          !
          if (headtt) print*,'viscous force: Smagorinsky_simplified'
          if (headtt) lvisc_LES=.true.
          if(ldensity) then
            !
            ! Find nu_smag
            !
            call multm2_mn(sij,sij2)
            SS12=sqrt(2*sij2)
            nu_smag=(C_smag*dxmax)**2.*SS12
            !
            ! Calculate viscous force
            !
            call del2v_etc(f,iuu,del2u,GRADDIV=graddivu)
            call multmv_mn(sij,glnrho,sglnrho)
            call multsv_mn(nu_smag,sglnrho,nusglnrho)
            tmp1=del2u+1./3.*graddivu
            call multsv_mn(nu_smag,tmp1,tmp2)
            fvisc=2*nusglnrho+tmp2
            diffus_nu=max(diffus_nu,nu_smag*dxyz_2)
            !
            ! Add ordinary viscosity if nu /= 0
            !
            if (nu /= 0.) then
              !
              !  viscous force: nu*(del2u+graddivu/3+2S.glnrho)
              !  -- the correct expression for nu=const
              !
              fvisc=fvisc+2*nu*sglnrho+nu*(del2u+1./3.*graddivu)
              diffus_nu=max(diffus_nu,nu*dxyz_2)
            endif
          else
            if(lfirstpoint) &
                 print*,"ldensity better be .true. for ivisc='smagorinsky'"
          endif
        case ('smagorinsky_cross_simplified')
          !
          !  viscous force: nu_smag*(del2u+graddivu/3+2S.glnrho)
          !  where nu_smag=(C_smag*dxmax)**2*sqrt(S:J)
          !
          if (headtt) print*,'viscous force: Smagorinsky_simplified'
          if (headtt) lvisc_LES=.true.
          if(ldensity) then
            !
            ! Need to calculate Jij
            !
            do j=1,3
              do i=1,3
                Jij(:,i,j)=.5*(bij(:,i,j)+bij(:,j,i))
              enddo
            enddo
            !
            ! Find nu_smag
            !
            call multmm_sc(sij,Jij,SJ)
            SS12=sqrt(abs(SJ))
            nu_smag=(C_smag*dxmax)**2.*SS12
            !
            ! Calculate viscous force
            !
            call del2v_etc(f,iuu,del2u,GRADDIV=graddivu)
            call multmv_mn(sij,glnrho,sglnrho)
            call multsv_mn(nu_smag,sglnrho,nusglnrho)
            tmp1=del2u+1./3.*graddivu
            call multsv_mn(nu_smag,tmp1,tmp2)
            fvisc=2*nusglnrho+tmp2
            diffus_nu=max(diffus_nu,nu_smag*dxyz_2)
            !
            ! Add ordinary viscosity if nu /= 0
            !
            if (nu /= 0.) then
              !
              !  viscous force: nu*(del2u+graddivu/3+2S.glnrho)
              !  -- the correct expression for nu=const
              !
               fvisc=fvisc+2*nu*sglnrho+nu*(del2u+1./3.*graddivu)
               diffus_nu=max(diffus_nu,nu*dxyz_2)
            endif
          else
            if(lfirstpoint) &
                 print*,"ldensity better be .true. for ivisc='smagorinsky'"
          endif
        case default
          !
          !  Catch unknown values
          !
          if (lroot) print*, 'No such such value for ivisc: ', trim(ivisc)
          call stop_it('calc_viscous_forcing')

        endselect

        df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)+fvisc
      else ! (nu=0)
        if (headtt) print*,'no viscous force: (nu=0)'
      endif
!
!  set viscous time step
!
      if (ldiagnos) then
         if (i_dtnu/=0) then
            call max_mn_name(diffus_nu/cdtv,i_dtnu,l_dt=.true.)
         endif
         if (i_nu_LES /= 0) then
            call sum_mn_name(nu_smag,i_nu_LES)
         endif
         if (i_epsK2/=0) then
           call dot_mn(f(l1:l2,m,n,iux:iuz),fvisc,ufvisc)
           rufvisc=ufvisc/rho1
           call sum_mn_name(-rufvisc,i_epsK2)
         endif
      endif
!
      if(ip==0) print*,divu  !(keep compiler quiet)
    end subroutine calc_viscous_force
!***********************************************************************

endmodule Viscosity
