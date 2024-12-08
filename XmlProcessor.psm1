# XmlProcessor.psm1
# Module for processing XML route data

function Get-lines {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $lines = @()
    $lineNodes = $xml.SelectNodes("//a:Line", $nsManager)
    
    foreach ($line in $lineNodes) {
        $waterSubmodeNode = $line.SelectSingleNode(".//a:WaterSubmode", $nsManager)
        
        $lines += [PSCustomObject]@{
            LineId = $line.GetAttribute("id")
            Version = $line.GetAttribute("version")
            Name = $line.SelectSingleNode(".//a:Name", $nsManager).InnerText
            TransportMode = $line.SelectSingleNode(".//a:TransportMode", $nsManager).InnerText
            WaterSubmode = if ($waterSubmodeNode) { $waterSubmodeNode.InnerText } else { "" }
            PublicCode = $line.SelectSingleNode(".//a:PublicCode", $nsManager).InnerText
            PrivateCode = $line.SelectSingleNode(".//a:PrivateCode", $nsManager).InnerText
            OperatorRef = $line.SelectSingleNode(".//a:OperatorRef", $nsManager).GetAttribute("ref")
            GroupRef = $line.SelectSingleNode(".//a:RepresentedByGroupRef", $nsManager).GetAttribute("ref")
        }
    }
    
    return $lines
}

function Get-routes {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $routes = @()
    $routeNodes = $xml.SelectNodes("//a:Route", $nsManager)
    
    foreach ($route in $routeNodes) {
        $routes += [PSCustomObject]@{
            RouteId = $route.GetAttribute("id")
            Version = $route.GetAttribute("version")
            Name = $route.SelectSingleNode(".//a:Name", $nsManager).InnerText
            ShortName = $route.SelectSingleNode(".//a:ShortName", $nsManager).InnerText
            LineRef = $route.SelectSingleNode(".//a:LineRef", $nsManager).GetAttribute("ref")
            DirectionType = $route.SelectSingleNode(".//a:DirectionType", $nsManager).InnerText
        }
    }
    
    return $routes
}

function Get-route_points {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $routePoints = @()
    $routeNodes = $xml.SelectNodes("//a:Route", $nsManager)
    
    foreach ($route in $routeNodes) {
        $points = $route.SelectNodes(".//a:PointOnRoute", $nsManager)
        foreach ($point in $points) {
            $routePointRef = $point.SelectSingleNode(".//a:RoutePointRef", $nsManager)
            
            $stopId = ""
            if ($routePointRef) {
                $ref = $routePointRef.GetAttribute("ref")
                if ($ref -match ":(\d+)_") {
                    $stopId = $matches[1]
                }
            }
            
            $routePoints += [PSCustomObject]@{
                RouteId = $route.GetAttribute("id")
                PointId = $point.GetAttribute("id")
                Version = $point.GetAttribute("version")
                Order = $point.GetAttribute("order")
                StopPlaceID = $stopId
                RoutePointRef = if ($routePointRef) { $routePointRef.GetAttribute("ref") } else { "" }
            }
        }
    }
    
    return $routePoints
}

function Get-journey_patterns {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $patterns = @()
    $patternNodes = $xml.SelectNodes("//a:JourneyPattern", $nsManager)
    
    foreach ($pattern in $patternNodes) {
        $direction = if ($pattern.GetAttribute("id") -match "Outbound|Inbound") { $matches[0] } else { "Unknown" }
        $nameNode = $pattern.SelectSingleNode(".//a:Name", $nsManager)
        $routeRefNode = $pattern.SelectSingleNode(".//a:RouteRef", $nsManager)
        
        $patterns += [PSCustomObject]@{
            JourneyPatternId = $pattern.GetAttribute("id")
            Version = $pattern.GetAttribute("version")
            Name = if ($nameNode) { $nameNode.InnerText } else { "" }
            Direction = $direction
            RouteRef = if ($routeRefNode) { $routeRefNode.GetAttribute("ref") } else { "" }
        }
    }
    
    return $patterns
}

function Get-stop_sequences {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $sequences = @()
    $patterns = $xml.SelectNodes("//a:JourneyPattern", $nsManager)
    
    foreach ($pattern in $patterns) {
        $stopPoints = $pattern.SelectNodes(".//a:StopPointInJourneyPattern", $nsManager)
        foreach ($stopPoint in $stopPoints) {
            $scheduledStopPointRef = $stopPoint.SelectSingleNode(".//a:ScheduledStopPointRef", $nsManager)
            $forBoarding = $stopPoint.SelectSingleNode(".//a:ForBoarding", $nsManager)
            $forAlighting = $stopPoint.SelectSingleNode(".//a:ForAlighting", $nsManager)
            $destinationDisplayRef = $stopPoint.SelectSingleNode(".//a:DestinationDisplayRef", $nsManager)
            
            $stopId = ""
            if ($scheduledStopPointRef) {
                $ref = $scheduledStopPointRef.GetAttribute("ref")
                if ($ref -match ":(\d+)_") {
                    $stopId = $matches[1]
                }
            }
            
            $sequences += [PSCustomObject]@{
                JourneyPatternId = $pattern.GetAttribute("id")
                StopSequenceId = $stopPoint.GetAttribute("id")
                Version = $stopPoint.GetAttribute("version")
                Order = $stopPoint.GetAttribute("order")
                StopPlaceID = $stopId
                ForBoarding = if ($forBoarding) { $forBoarding.InnerText } else { "true" }
                ForAlighting = if ($forAlighting) { $forAlighting.InnerText } else { "true" }
                DestinationDisplayRef = if ($destinationDisplayRef) { $destinationDisplayRef.GetAttribute("ref") } else { "" }
            }
        }
    }
    
    return $sequences
}

function Get-service_journeys {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $journeys = @()
    $journeyNodes = $xml.SelectNodes("//a:ServiceJourney", $nsManager)
    
    foreach ($journey in $journeyNodes) {
        $nameNode = $journey.SelectSingleNode(".//a:Name", $nsManager)
        $privateCodeNode = $journey.SelectSingleNode(".//a:PrivateCode", $nsManager)
        $journeyPatternRefNode = $journey.SelectSingleNode(".//a:JourneyPatternRef", $nsManager)
        $operatorRefNode = $journey.SelectSingleNode(".//a:OperatorRef", $nsManager)
        $lineRefNode = $journey.SelectSingleNode(".//a:LineRef", $nsManager)
        
        $journeys += [PSCustomObject]@{
            ServiceJourneyId = $journey.GetAttribute("id")
            Version = $journey.GetAttribute("version")
            Name = if ($nameNode) { $nameNode.InnerText } else { "" }
            PrivateCode = if ($privateCodeNode) { $privateCodeNode.InnerText } else { "" }
            JourneyPatternRef = if ($journeyPatternRefNode) { $journeyPatternRefNode.GetAttribute("ref") } else { "" }
            OperatorRef = if ($operatorRefNode) { $operatorRefNode.GetAttribute("ref") } else { "" }
            LineRef = if ($lineRefNode) { $lineRefNode.GetAttribute("ref") } else { "" }
        }
    }
    
    return $journeys
}

function Get-passing_times {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $passingTimes = @()
    $journeys = $xml.SelectNodes("//a:ServiceJourney", $nsManager)
    
    foreach ($journey in $journeys) {
        $times = $journey.SelectNodes(".//a:TimetabledPassingTime", $nsManager)
        $sequence = 1
        
        foreach ($time in $times) {
            $timeId = $time.GetAttribute("id")
            $scheduledTime = if ($timeId -match "_(\d{2})_(\d{2})_(\d{2})$") {
                "$($matches[1]):$($matches[2]):$($matches[3])"
            } else { "" }
            
            # Get stopPlaceId from the corresponding stop point
            $journeyPatternRef = $journey.SelectSingleNode(".//a:JourneyPatternRef", $nsManager).GetAttribute("ref")
            $stopPoint = $xml.SelectSingleNode("//a:JourneyPattern[@id='$journeyPatternRef']//a:StopPointInJourneyPattern[$sequence]//a:ScheduledStopPointRef", $nsManager)
            
            $stopPlaceId = ""
            if ($stopPoint) {
                $ref = $stopPoint.GetAttribute("ref")
                if ($ref -match ":(\d+)_") {
                    $stopPlaceId = $matches[1]
                }
            }
            
            $passingTimes += [PSCustomObject]@{
                PassingTimeId = $timeId
                ServiceJourneyId = $journey.GetAttribute("id")
                StopPlaceID = $stopPlaceId
                ScheduledTime = $scheduledTime
                SequenceNumber = $sequence
                Version = $time.GetAttribute("version")
            }
            $sequence++
        }
    }
    
    return $passingTimes
}

function Get-dated_journeys {
    param(
        [Parameter(Mandatory=$true)]
        [xml]$xml,
        
        [Parameter(Mandatory=$true)]
        [System.Xml.XmlNamespaceManager]$nsManager
    )
    
    $datedJourneys = @()
    $journeyNodes = $xml.SelectNodes("//a:DatedServiceJourney", $nsManager)
    
    foreach ($journey in $journeyNodes) {
        $serviceJourneyRef = $journey.SelectSingleNode(".//a:ServiceJourneyRef", $nsManager)
        $operatingDayRef = $journey.SelectSingleNode(".//a:OperatingDayRef", $nsManager)
        
        $operatingDate = ""
        if ($operatingDayRef) {
            $ref = $operatingDayRef.GetAttribute("ref")
            if ($ref -match ":\d{4}-\d{2}-\d{2}$") {
                $operatingDate = $matches[0].Substring(1)
            }
        }
        
        $datedJourneys += [PSCustomObject]@{
            DatedServiceJourneyId = $journey.GetAttribute("id")
            Version = $journey.GetAttribute("version")
            ServiceJourneyRef = if ($serviceJourneyRef) { $serviceJourneyRef.GetAttribute("ref") } else { "" }
            OperatingDate = $operatingDate
        }
    }
    
    return $datedJourneys
}

# Export all functions
Export-ModuleMember -Function Get-lines, Get-routes, Get-route_points, Get-journey_patterns, 
                              Get-stop_sequences, Get-service_journeys, Get-passing_times, Get-dated_journeys
