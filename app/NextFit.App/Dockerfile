FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build 
WORKDIR /src

COPY NextFit.App.csproj ./
RUN dotnet restore

COPY . ./
RUN dotnet publish -c Release -o /out /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime
WORKDIR /app 

ENV ASPNETCORE_URLS=HTTP://+:8080
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=true

RUN addgroup -S appgroup && adduser -S appuser -G appgroup -u 10001

COPY --from=build /out ./

USER appuser

EXPOSE 8080

ENTRYPOINT ["dotnet", "NextFit.App.dll"]
