% calculates Ertel PV at interior RHO points (horizontal plane) and midway between rho points in the vertical
%       [pv] = roms_pv(fname,tindices)

function [pv,xpv,ypv,zpv] = roms_pv(fname,tindices,outname)

% parameters
%lam = 'rho';
vinfo = ncinfo(fname,'u');
s     = vinfo.Size;
dim   = length(s); 
slab  = roms_slab(fname,0);

warning off
grid = roms_get_grid(fname,fname,0,1);
warning on

% parse input
if ~exist('tindices','var'), tindices = []; end

[iend,tindices,dt,nt,stride] = roms_tindices(tindices,slab,vinfo.Size(end));

rho0  = ncread(fname,'R0');
tpv = ncread(fname,'ocean_time');
tpv = tpv([tindices(1):tindices(2)]);
f   = ncread(fname,'f',[1 1],[Inf Inf]);
f   = mean(f(:));

xpv = grid.x_rho(1,2:end-1)';
ypv = grid.y_rho(2:end-1,1)';
zpv = avg1(grid.z_r(:,1,1));

xname = 'x_pv'; yname = 'y_pv'; zname = 'z_pv'; tname = 'ocean_time';

grid1.xv = grid.x_v(1,:)';
grid1.yv = grid.y_v(:,1);
grid1.zv = grid.z_v(:,1,1);

grid1.xu = grid.x_u(1,:)';
grid1.yu = grid.y_u(:,1);
grid1.zu = grid.z_u(:,1,1);

grid1.xr = grid.x_rho(1,:)';
grid1.yr = grid.y_rho(:,1);
grid1.zr = grid.z_r(:,1,1);

%% setup netcdf file
if ~exist('outname','var') || isempty(outname), outname = 'ocean_pv.nc'; end
if exist(outname,'file')
    in = input('File exists. Do you want to overwrite (1/0)? ');
    if in == 1, delete(outname); end
end
try
    nccreate(outname,'pv','Dimensions', {xname s(1)-1 yname s(2)-2 zname s(3)-1 tname length(tpv)});
    nccreate(outname,xname,'Dimensions',{xname s(1)-1});
    nccreate(outname,yname,'Dimensions',{yname s(2)-2});
    nccreate(outname,zname,'Dimensions',{zname s(3)-1});
    nccreate(outname,tname,'Dimensions',{tname length(tpv)});
    
    ncwriteatt(outname,'pv','Description','Ertel PV calculated from ROMS output');
    ncwriteatt(outname,'pv','coordinates','x_pv y_pv z_pv ocean_time');
    ncwriteatt(outname,'pv','units','N/A');
    ncwriteatt(outname,xname,'units',ncreadatt(fname,'x_u','units'));
    ncwriteatt(outname,yname,'units',ncreadatt(fname,'y_u','units'));
    ncwriteatt(outname,zname,'units','m');
    ncwriteatt(outname,tname,'units','s');
    fprintf('\n Created file : %s\n', outname);
catch ME
    fprintf('\n Appending to existing file.\n');
end

ncwrite(outname,xname,xpv);
ncwrite(outname,yname,ypv);
ncwrite(outname,zname,zpv);
ncwrite(outname,'ocean_time',tpv);

%% calculate pv
pv = nan([s(1)-1 s(2)-2 s(3)-1 tindices(2)-tindices(1)+1]);

for i=0:iend-1
    [read_start,read_count] = roms_ncread_params(dim,i,iend,slab,tindices,dt);
    tstart = read_start(end);
    tend   = read_start(end) + read_count(end) -1;
    
    u      = ncread(fname,'u',read_start,read_count,stride);
    v      = ncread(fname,'v',read_start,read_count,stride);
    rho = ncread(fname,'rho',read_start,read_count,stride); % theta
    
    [pv(:,:,:,tstart:tend),xpv,ypv,zpv] = pv_cgrid(grid1,u,v,rho,f,rho0);

    ncwrite(outname,'pv',pv(:,:,:,tstart:tend),read_start); 
    
end
intPV = domain_integrate(pv,xpv,ypv,zpv);
save pv.mat pv xpv ypv zpv tpv intPV
fprintf('\n Wrote file : %s \n\n',outname);

    %% old code
    
%     pv1    = avgx(avgz(bsxfun(@plus,avgy(vx - uy),f)))  .*  (tz(2:end-1,2:end-1,:,:));
%     pv2    = (-1)*;
%     pv3    = uz.*avgz(tx);
    %pv = double((pv1 + avgy(pv2(2:end-1,:,:,:)) + avgx(pv3(:,2:end-1,:,:)))./avgz(lambda(2:end-1,2:end-1,:,:))); 