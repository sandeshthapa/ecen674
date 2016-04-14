function [sys,x0,str,ts,simStateCompliance] = guidance_model_2(t,x,u,flag,P)

switch flag,

  %%%%%%%%%%%%%%%%%%
  % Initialization %
  %%%%%%%%%%%%%%%%%%
  case 0,
    [sys,x0,str,ts,simStateCompliance]=mdlInitializeSizes(P);

  %%%%%%%%%%%%%%%
  % Derivatives %
  %%%%%%%%%%%%%%%
  case 1,
    sys=mdlDerivatives(t,x,u,P);

  %%%%%%%%%%
  % Update %
  %%%%%%%%%%
  case 2,
    sys=mdlUpdate(t,x,u);

  %%%%%%%%%%%
  % Outputs %
  %%%%%%%%%%%
  case 3,
    sys=mdlOutputs(t,x,u,P);

  %%%%%%%%%%%%%%%%%%%%%%%
  % GetTimeOfNextVarHit %
  %%%%%%%%%%%%%%%%%%%%%%%
  case 4,
    sys=mdlGetTimeOfNextVarHit(t,x,u);

  %%%%%%%%%%%%%
  % Terminate %
  %%%%%%%%%%%%%
  case 9,
    sys=mdlTerminate(t,x,u);

  %%%%%%%%%%%%%%%%%%%%
  % Unexpected flags %
  %%%%%%%%%%%%%%%%%%%%
  otherwise
    DAStudio.error('Simulink:blocks:unhandledFlag', num2str(flag));

end

% end sfuntmpl

%
%=============================================================================
% mdlInitializeSizes
% Return the sizes, initial conditions, and sample times for the S-function.
%=============================================================================
%
function [sys,x0,str,ts,simStateCompliance]=mdlInitializeSizes(P)

%
% call simsizes for a sizes structure, fill it in and convert it to a
% sizes array.
%
% Note that in this example, the values are hard coded.  This is not a
% recommended practice as the characteristics of the block are typically
% defined by the S-function parameters.
%
sizes = simsizes;

sizes.NumContStates  = 7;
sizes.NumDiscStates  = 0;
sizes.NumOutputs     = 16+12;
sizes.NumInputs      = 3;
sizes.DirFeedthrough = 0;
sizes.NumSampleTimes = 1;   % at least one sample time is needed

sys = simsizes(sizes);

%
% initialize the initial conditions
%
x0  = [...
    P.pn0;...    % initial North position
    P.pe0;...    % initial East position
    P.psi0;...   % initial heading
    -P.pd0;...   % initial altitude
    0;...        % initial climb rate
    P.Va0;...    % initial airspeed
    0;...        % initial roll angle    
    ];

%
% str is always an empty matrix
%
str = [];

%
% initialize the array of sample times
%
ts  = [0 0];

% Specify the block simStateCompliance. The allowed values are:
%    'UnknownSimState', < The default setting; warn and assume DefaultSimState
%    'DefaultSimState', < Same sim state as a built-in block
%    'HasNoSimState',   < No sim state
%    'DisallowSimState' < Error out when saving or restoring the model sim state
simStateCompliance = 'UnknownSimState';

% end mdlInitializeSizes

%
%=============================================================================
% mdlDerivatives
% Return the derivatives for the continuous states.
%=============================================================================
%
function sys=mdlDerivatives(t,x,u,P)
  pn     = x(1); % North position
  pe     = x(2); % East position
  psi    = x(3); % heading
  h      = x(4); % altitude 
  hdot   = x(5); % climb rate
  Va     = x(6); % airspeed
  phi    = x(7); % roll
  Va_c   = u(1); % commanded airspeed
  h_c    = u(2); % commanded altitude
  phi_c  = u(3); % commanded roll angle

%   psi = chi - asin((P.wind_n*(-sin(chi)) + P.wind_e*cos(chi))/Va);
  pndot = Va*cos(psi) + P.wind_n;
  pedot = Va*sin(psi) + P.wind_e;
  psidot = P.gravity/Va*tan(phi);
  hdot_c = 0;
  hddot = P.b_hdot * (hdot_c - hdot) + P.b_h * (h_c - h);
  Vadot = P.b_va * (Va_c - Va);
  phidot = P.b_phi * (phi_c - phi);
  
sys = [...
    pndot;...
    pedot;...
    psidot;...
    hdot;...
    hddot;...
    Vadot;...
    phidot;...
    ];

% end mdlDerivatives

%
%=============================================================================
% mdlUpdate
% Handle discrete state updates, sample time hits, and major time step
% requirements.
%=============================================================================
%
function sys=mdlUpdate(t,x,u)

sys = [];

% end mdlUpdate

%
%=============================================================================
% mdlOutputs
% Return the block outputs.
%=============================================================================
%
function sys=mdlOutputs(t,x,u,P)
  pn     = x(1); % North position
  pe     = x(2); % East position
  psi    = x(3); % heading
  h      = x(4); % altitude
  hdot   = x(5); % climb rate
  Va     = x(6); % airspeed
  phi    = x(7); % roll
  
  alpha  = 0;
  beta   = 0;

  % wind speed
  wn = P.wind_n;
  we = P.wind_e;
  
  % solve for heading and groundspeed
%   psi = chi - asin( (-P.wind_n*sin(chi)+P.wind_e*cos(chi))/Va );
  chi = psi;
  Vg  = [cos(chi), sin(chi)]*(Va*[cos(psi); sin(psi)] + [wn; we]); 

  % roll angle is given by psidot = g/V*tan(phi)
%   phi     = atan(Vg*chidot/P.gravity);
  
  % letting theta equal flight path angle given by hdot = V sin(gamma)
  if hdot/Va > 1
      temp = 1;
  elseif hdot/Va < -1
      temp = -1;
  else
      temp = hdot/Va;
  end
  theta = asin(temp);
    
  % set angular rates to zero
  p     = 0;
  q     = 0;
  r     = 0;
  
  
% output the same states that are returned by the state estimation block
%   pnhat    - estimated North position, 
%   pehat    - estimated East position, 
%   hhat     - estimated altitude, 
%   Vahat    - estimated airspeed, 
%   alphahat - estimated angle of attack
%   betahat  - estimated sideslip angle
%   phihat   - estimated roll angle, 
%   thetahat - estimated pitch angel, 
%   chihat   - estimated course, 
%   phat     - estimated roll rate, 
%   qhat     - estimated pitch rate, 
%   rhat     - estimated yaw rate,
%   Vghat    - estimated ground speed, 
%   wnhat    - estimate of North wind, 
%   wehat    - estimate of East wind
%   psihat   - estimate of heading angle
% also need to return the normal state vector so that we don't need to
% change the drawing routine.
sys = [pn; pe; h; Va; alpha; beta; phi; theta; chi; p; q; r; Vg; wn; we; psi;...
    pn; pe; -h; Va; 0; 0; phi; theta; psi; p; q; r];
    



% end mdlOutputs

%
%=============================================================================
% mdlGetTimeOfNextVarHit
% Return the time of the next hit for this block.  Note that the result is
% absolute time.  Note that this function is only used when you specify a
% variable discrete-time sample time [-2 0] in the sample time array in
% mdlInitializeSizes.
%=============================================================================
%
function sys=mdlGetTimeOfNextVarHit(t,x,u)

sampleTime = 1;    %  Example, set the next hit to be one second later.
sys = t + sampleTime;

% end mdlGetTimeOfNextVarHit

%
%=============================================================================
% mdlTerminate
% Perform any end of simulation tasks.
%=============================================================================
%
function sys=mdlTerminate(t,x,u)

sys = [];

% end mdlTerminate
