! $Id$
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lborder_profiles = .true.
!
! PENCILS PROVIDED rborder_mn
!
!***************************************************************

module BorderProfiles

  use Cparam
  use Cdata

  implicit none

  private

  include 'border_profiles.h'
!
!  border_prof_[x-z] could be of size n[x-z], but having the same
!  length as f() (in the given dimension) gives somehow more natural code.
!
  real, dimension(mx) :: border_prof_x=1.0
  real, dimension(my) :: border_prof_y=1.0
  real, dimension(mz) :: border_prof_z=1.0
!
  contains

!***********************************************************************
    subroutine initialize_border_profiles()
!
!  Position-dependent quenching factor that multiplies rhs of pde
!  by a factor that goes gradually to zero near the boundaries.
!  border_frac_[xyz] is a 2-D array, separately for all three directions.
!  border_frac_[xyz]=1 would affect everything between center and border.
!
      use Cdata
      use Messages
!
      real, dimension(nx) :: xi
      real, dimension(ny) :: eta
      real, dimension(nz) :: zeta
      real :: border_width, lborder, uborder
      integer :: l
!
!  x-direction
!
      border_prof_x(l1:l2)=1
!
      if (border_frac_x(1)>0) then
        if (lperi(1)) call fatal_error('initialize_border_profiles', &
            'must have lperi(1)=F for border profile in x')
        border_width=border_frac_x(1)*Lxyz(1)/2
        lborder=xyz0(1)+border_width
        xi=1-max(lborder-x(l1:l2),0.0)/border_width
        border_prof_x(l1:l2)=min(border_prof_x(l1:l2),xi**2*(3-2*xi))
      endif
!
      if (border_frac_x(2)>0) then
        if (lperi(1)) call fatal_error('initialize_border_profiles', &
            'must have lperi(1)=F for border profile in x')
        border_width=border_frac_x(2)*Lxyz(1)/2
        uborder=xyz1(1)-border_width
        xi=1-max(x(l1:l2)-uborder,0.0)/border_width
        border_prof_x(l1:l2)=min(border_prof_x(l1:l2),xi**2*(3-2*xi))
      endif
!
!  y-direction
!
      border_prof_y(m1:m2)=1
!
      if (border_frac_y(1)>0) then
        if (lperi(2)) call fatal_error('initialize_border_profiles', &
            'must have lperi(2)=F for border profile in y')
        border_width=border_frac_y(1)*Lxyz(2)/2
        lborder=xyz0(2)+border_width
        eta=1-max(lborder-y(m1:m2),0.0)/border_width
        border_prof_y(m1:m2)=min(border_prof_y(m1:m2),eta**2*(3-2*eta))
      endif
!
      if (border_frac_y(2)>0) then
        if (lperi(2)) call fatal_error('initialize_border_profiles', &
            'must have lperi(2)=F for border profile in y')
        border_width=border_frac_y(2)*Lxyz(2)/2
        uborder=xyz1(2)-border_width
        eta=1-max(y(m1:m2)-uborder,0.0)/border_width
        border_prof_y(m1:m2)=min(border_prof_y(m1:m2),eta**2*(3-2*eta))
      endif
!
!  z-direction
!
      border_prof_z(n1:n2)=1
!
      if (border_frac_z(1)>0) then
        if (lperi(3)) call fatal_error('initialize_border_profiles', &
            'must have lperi(3)=F for border profile in z')
        border_width=border_frac_z(1)*Lxyz(3)/2
        lborder=xyz0(3)+border_width
        zeta=1-max(lborder-z(n1:n2),0.0)/border_width
        border_prof_z(n1:n2)=min(border_prof_z(n1:n2),zeta**2*(3-2*zeta))
      endif
!
      if (border_frac_z(2)>0) then
        if (lperi(3)) call fatal_error('initialize_border_profiles', &
            'must have lperi(3)=F for border profile in z')
        border_width=border_frac_z(2)*Lxyz(3)/2
        uborder=xyz1(3)-border_width
        zeta=1-max(z(n1:n2)-uborder,0.0)/border_width
        border_prof_z(n1:n2)=min(border_prof_z(n1:n2),zeta**2*(3-2*zeta))
      endif
!
!  Write border profiles to file.
!
      open(1,file=trim(directory_snap)//'/border_prof_x.dat')
        do l=1,mx
          write(1,'(2f15.6)') x(l), border_prof_x(l)
        enddo
      close(1)
!
      open(1,file=trim(directory_snap)//'/border_prof_y.dat')
        do m=1,my
          write(1,'(2f15.6)') y(m), border_prof_y(m)
        enddo
      close(1)
!
      open(1,file=trim(directory_snap)//'/border_prof_z.dat')
        do n=1,mz
          write(1,'(2f15.6)') z(n), border_prof_z(n)
        enddo
      close(1)
!
    endsubroutine initialize_border_profiles
!***********************************************************************
    subroutine pencil_criteria_borderprofiles()
!
!  All pencils that this module depends on are specified here.
!
!  25-dec-06/wolf: coded
!
      use Cdata
!
      if (lcylindrical_coords.or.lcylinder_in_a_box) then
        lpenc_requested(i_rcyl_mn)=.true.
        lpenc_requested(i_rcyl_mn1)=.true.
      elseif (lspherical_coords.or.lsphere_in_a_box) then
        lpenc_requested(i_r_mn)=.true.
        lpenc_requested(i_r_mn1)=.true.
      else
        lpenc_requested(i_x_mn)=.true.
      endif
!
      if (.not.lspherical_coords) then
        lpenc_requested(i_phix)=.true.
        lpenc_requested(i_phiy)=.true.
      endif
!
      lpenc_requested(i_rborder_mn)=.true.
      
!
    endsubroutine pencil_criteria_borderprofiles
!***********************************************************************
    subroutine calc_pencils_borderprofiles(f,p)
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
!
      if (lpencil(i_rborder_mn)) then 
        if (lcylinder_in_a_box.or.lcylindrical_coords) then
          p%rborder_mn = p%rcyl_mn
        elseif (lsphere_in_a_box.or.lspherical_coords) then
          p%rborder_mn = p%r_mn
        else
          p%rborder_mn = p%x_mn
        endif
      endif
!
    endsubroutine calc_pencils_borderprofiles
!***********************************************************************
    subroutine border_driving(f,df,p,f_target,j)
!
!  Position-dependent driving term that attempts to drive pde
!  the variable toward some target solution on the boundary.
!
      real, dimension (mx,my,mz,mfarray) :: f
      type (pencil_case) :: p
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension(nx) :: f_target
      real :: pborder,inverse_drive_time
      integer :: i,j
!

!
      do i=1,nx
        if ( ((p%rcyl_mn(i).ge.r_int).and.(p%rcyl_mn(i).le.r_int+2*wborder_int)).or.&
             ((p%rcyl_mn(i).ge.r_ext-2*wborder_ext).and.(p%rcyl_mn(i).le.r_ext))) then
!        
          call get_drive_time(p,inverse_drive_time,i)
          call get_border(p,pborder,i)
        
          df(i+l1-1,m,n,j) = df(i+l1-1,m,n,j) &
               - (f(i+l1-1,m,n,j) - f_target(i))*pborder*inverse_drive_time
          !if (j==ilnrho) print*,pborder,inverse_drive_time,f_target(i)
        endif
      !else do nothing
      !df(l1:l2,m,n,j) = df(l1:l2,m,n,j) 
      enddo
!
    endsubroutine border_driving
!***********************************************************************
    subroutine get_border(p,pborder,i)
!
! Apply a step function that smoothly goes from zero to one on both sides.
! In practice, means that the driving takes place
! from r_int to r_int+2*wborder_int, and
! from r_ext-2*wborder_ext to r_ext
!
! Regions away from these limits are unaffected.
!
! 28-Jul-06/wlad : coded
!
      use Sub, only: cubic_step
!
      real, intent(out) :: pborder
      type (pencil_case) :: p
      real :: rlim_mn
      integer :: i
!
      if (lcylinder_in_a_box.or.lcylindrical_coords) then
         rlim_mn = p%rcyl_mn(i)
      elseif (lsphere_in_a_box.or.lspherical_coords) then
         rlim_mn = p%r_mn(i)
      else
         rlim_mn = p%x_mn(i)
      endif
!
! cint = 1-step_int , cext = step_ext
! pborder = cint+cext
!
      pborder = 1-cubic_step(rlim_mn,r_int,wborder_int,SHIFT=1.) + &
           cubic_step(rlim_mn,r_ext,wborder_ext,SHIFT=-1.)
!
    endsubroutine get_border
!***********************************************************************
    subroutine get_drive_time(p,inverse_drive_time,i)
!
! This is problem-dependent, since the driving should occur in the
! typical time-scale of the problem. Currently, only the keplerian
! orbital time is implemented.
!
! 28-Jul-06/wlad : coded
!
      real, intent(out) :: inverse_drive_time
      real :: uphi
      type (pencil_case) :: p
      integer :: i
!
      if (lcartesian_coords.or.lcylindrical_coords) then
        uphi=p%uu(i,1)*p%phix(i)+p%uu(i,2)*p%phiy(i)
      elseif (lspherical_coords) then
        uphi=p%uu(i,3)
      endif
!
      inverse_drive_time = .5*pi_1*uphi/p%rborder_mn(i)
!
    endsubroutine get_drive_time
!***********************************************************************
    subroutine border_quenching(df,j)
!
      real, dimension (mx,my,mz,mvar) :: df
      integer :: j
!
!  Position-dependent quenching factor that multiplies rhs of pde
!  by a factor that goes gradually to zero near the boundaries.
!  border_frac_[xyz] is a 2-D array, separately for all three directions.
!  border_frac_[xyz]=1 would affect everything between center and border.
!
       df(l1:l2,m,n,j) = df(l1:l2,m,n,j) &
          *border_prof_x(l1:l2)*border_prof_y(m)*border_prof_z(n)
!
    endsubroutine border_quenching
!***********************************************************************
endmodule BorderProfiles
